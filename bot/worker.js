// Bot Telegram -> Firebase Realtime Database untuk aplikasi Catatan Simpel.
// Aplikasi di HP sudah listen realtime ke Firebase, jadi data yang ditulis
// di sini otomatis masuk ke SQLite lokal.
//
// Perintah:
//   #keluar 50000 bensin @toko     -> usaha_kas (Pengeluaran)
//   #masuk 200rb jual kopi @warung -> usaha_kas (Pemasukan)
//   #catat beli sabun              -> tambah ke catatan aktif, atau catatan
//                                     baru (baris pertama = judul)
//   /folder                        -> pilih folder aktif (tombol)
// Folder tujuan: @folder di pesan > folder aktif > tanya lewat tombol.
//
// Secret (wrangler secret put ...): BOT_TOKEN, ALLOWED_ID, WEBHOOK_SECRET

const DB = 'https://kas-keluarga-47d2d-default-rtdb.asia-southeast1.firebasedatabase.app';

export default {
  async fetch(req, env) {
    if (req.method !== 'POST') return new Response('ok');
    if (req.headers.get('X-Telegram-Bot-Api-Secret-Token') !== env.WEBHOOK_SECRET) {
      return new Response('forbidden', { status: 403 });
    }
    const update = await req.json();
    try {
      if (update.callback_query) await onButton(update.callback_query, env);
      else if (update.message?.text) await onMessage(update.message, env);
    } catch (e) {
      const chat = update.message?.chat.id ?? update.callback_query?.message.chat.id;
      if (chat) await tg(env, 'sendMessage', { chat_id: chat, text: `❌ Error: ${e.message}` });
    }
    return new Response('ok');
  },

  // Jadwal di wrangler.toml (UTC): "0 23 * * *" = 06.00 WIB, sisanya pengingat.
  async scheduled(event, env) {
    await (event.cron === '0 23 * * *' ? laporanPagi(env) : pengingat(env));
  },
};

// ---------- Firebase ----------

const fb = async (path, method = 'GET', body) => {
  const res = await fetch(`${DB}/${path}.json`, {
    method,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`Firebase ${method} ${path}: ${res.status}`);
  return res.json();
};

// Firebase bisa mengembalikan object ATAU array (lihat _asRecordList di app).
const records = (data) => Object.values(data ?? {}).filter((r) => r && r.id != null);

// Tabel & nama kolom folder per jenis perintah.
const KIND = {
  kas: { folders: 'usaha_folders', name: 'nama' },
  note: { folders: 'folders', name: 'name' },
};

async function folders(kind) {
  return records(await fb(KIND[kind].folders)).map((f) => ({ id: f.id, name: f[KIND[kind].name] }));
}

// ---------- Telegram ----------

const tg = (env, method, body) =>
  fetch(`https://api.telegram.org/bot${env.BOT_TOKEN}/${method}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });

/** Susun tombol 2 per baris. */
const grid = (buttons) => {
  const rows = [];
  for (let i = 0; i < buttons.length; i += 2) rows.push(buttons.slice(i, i + 2));
  return rows;
};

const reply = (env, chat, text, extra = {}) => tg(env, 'sendMessage', { chat_id: chat, text, ...extra });

// ---------- Parsing ----------

/** "50000", "50.000", "50rb", "15k", "1,5jt", "2juta" -> angka rupiah. */
export function parseNominal(s) {
  const m = /^(\d+(?:[.,]\d+)*)(rb|ribu|k|jt|juta)?$/i.exec(s);
  if (!m) return null;
  const unit = (m[2] ?? '').toLowerCase();
  let num = m[1];
  if (unit) num = num.replace(',', '.'); // 1,5jt -> 1.5
  else num = num.replace(/[.,]/g, ''); // 50.000 -> 50000
  const mult = { rb: 1e3, ribu: 1e3, k: 1e3, jt: 1e6, juta: 1e6 }[unit] ?? 1;
  const n = Math.round(parseFloat(num) * mult);
  return Number.isFinite(n) && n > 0 ? n : null;
}

/** Ambil "@nama" dari teks. */
function takeFolder(text) {
  const m = /(?:^|\s)@(\S+)/.exec(text);
  return { folder: m?.[1] ?? null, rest: m ? text.replace(m[0], ' ').trim() : text.trim() };
}

function matchFolder(list, q) {
  if (!q) return null;
  q = q.toLowerCase();
  const exact = list.filter((f) => f.name.toLowerCase() === q);
  if (exact.length === 1) return exact[0];
  const partial = list.filter((f) => f.name.toLowerCase().includes(q));
  return partial.length === 1 ? partial[0] : null;
}

/** Tanggal WIB format yyyy-MM-dd (sama dengan app), geser [days] hari. */
const today = (days = 0) => new Date(Date.now() + 7 * 3600e3 + days * 864e5).toISOString().slice(0, 10);

/** "kemarin", "kmrn", "25/9", "25/9/2026", "25-09-26" -> yyyy-MM-dd, selain itu null. */
export function parseTanggal(w) {
  w = w.toLowerCase();
  if (w === 'kemarin' || w === 'kmrn') return today(-1);
  const m = /^(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2}|\d{4}))?$/.exec(w);
  if (!m) return null;
  const y = m[3] ? (m[3].length === 2 ? '20' + m[3] : m[3]) : today().slice(0, 4);
  const iso = `${y}-${m[2].padStart(2, '0')}-${m[1].padStart(2, '0')}`;
  const d = new Date(iso + 'T00:00:00Z');
  return !isNaN(d) && d.toISOString().startsWith(iso) ? iso : null;
}

const rupiah = (n) => 'Rp' + n.toLocaleString('id-ID');

// ---------- Handler ----------

async function onMessage(msg, env) {
  const chat = msg.chat.id;
  if (String(msg.from.id) !== env.ALLOWED_ID) return; // abaikan orang lain

  const text = msg.text.trim();
  const [cmd, ...words] = text.split(/\s+/);

  if (cmd === '/start' || cmd === '/help') {
    return reply(env, chat,
      'Cara 1 - pilih sekali lewat /folder, lalu:\n#keluar 50000 bensin\n#masuk 200rb jual kopi\n#catat beli sabun\n\n' +
      'Cara 2 - langsung sebut tujuan:\n#keluar 15rb parkir @toko\n#catat @belanja/bulanan beras 5kg\n(cukup sebagian nama, tanpa spasi)\n\n' +
      'Tanggal lain: #keluar 50rb bensin kemarin / 25/9\n\n' +
      'Saldo:\n/saldo = folder aktif\n/saldo @toko\n/saldo semua\n\nLaporan:\n/hariini · /hariini kemarin · /hariini 25/9\n/bulan · /bulan lalu · /bulan agustus · /bulan 12/2025\n(tambah @toko untuk satu folder)\nOtomatis: laporan jam 06.00, pengingat tiap 3 jam (09-21)\n\n/hapus = batalkan input terakhir');
  }

  if (cmd === '/folder') return reply(env, chat, 'Pilih jenis folder yang mau diaktifkan:', {
    reply_markup: { inline_keyboard: [[
      { text: '💰 Folder Usaha', callback_data: 'l:kas' },
      { text: '📝 Folder Catatan', callback_data: 'l:note' },
    ]] },
  });

  if (cmd === '/hapus') return reply(env, chat, await undo(chat));

  // /hariini [tanggal] [@folder], /bulan [bulan [tahun]] [@folder] -> default semua folder usaha.
  if (cmd === '/hariini' || cmd === '/bulan') {
    const { folder: arg, rest } = takeFolder(words.join(' '));
    let only = null;
    if (arg) {
      only = matchFolder(await folders('kas'), arg);
      if (!only) return reply(env, chat, `⚠️ Folder "${arg}" tidak ketemu (atau lebih dari satu yang cocok).`);
    }
    if (cmd === '/hariini') {
      const iso = rest ? parseTanggal(rest) : today();
      if (!iso) return reply(env, chat, '⚠️ Tanggal tidak dikenali. Contoh: /hariini kemarin, /hariini 25/9');
      return reply(env, chat, await laporanHari(only, iso));
    }
    const ym = rest ? parseBulan(rest) : today().slice(0, 7);
    if (!ym) return reply(env, chat, '⚠️ Bulan tidak dikenali. Contoh: /bulan 8, /bulan agustus, /bulan lalu, /bulan 12/2025');
    return reply(env, chat, await laporanBulan(ym, only));
  }

  // /saldo [@folder | semua] -> default folder usaha aktif, kalau belum ada: semua.
  if (cmd === '/saldo') {
    const arg = words[0]?.replace(/^@/, '');
    const list = await folders('kas');
    let pick;
    if (arg && arg !== 'semua') {
      const f = matchFolder(list, arg);
      if (!f) return reply(env, chat, `⚠️ Folder "${arg}" tidak ketemu (atau lebih dari satu yang cocok).`);
      pick = [f];
    } else {
      const activeId = arg ? null : (await fb(`bot_state/${chat}`))?.kas;
      const active = list.find((f) => f.id === activeId);
      pick = active ? [active] : list;
    }
    return reply(env, chat, await saldoText(pick));
  }

  let entry;
  const c = cmd.toLowerCase();
  if (c === '#keluar' || c === '#masuk') {
    const { folder, rest } = takeFolder(words.join(' '));
    const [nom, ...ket] = rest.split(/\s+/);
    const nominal = parseNominal(nom ?? '');
    if (!nominal) return reply(env, chat, '⚠️ Nominal tidak valid. Contoh: #keluar 50000 bensin');
    // Kata tanggal (kemarin / 25/9) boleh di mana saja di keterangan.
    const i = ket.findIndex((w) => parseTanggal(w));
    const tanggal = i >= 0 ? parseTanggal(ket.splice(i, 1)[0]) : today();
    entry = {
      kind: 'kas',
      folder,
      tipe: c === '#masuk' ? 'Pemasukan' : 'Pengeluaran',
      nominal,
      keterangan: ket.join(' ') || '-',
      tanggal,
    };
  } else if (c === '#catat') {
    const { folder, rest } = takeFolder(text.slice(cmd.length));
    if (!rest) return reply(env, chat, '⚠️ Isi catatan kosong. Contoh: #catat @belanja beli sabun');
    const [title, ...body] = rest.split('\n');
    entry = { kind: 'note', folder, text: rest, title: title.trim(), content: body.join('\n').trim() };
  } else {
    return; // bukan perintah, abaikan
  }

  // #catat @folder/catatan isi -> langsung tambahkan ke catatan itu.
  if (entry.kind === 'note' && entry.folder?.includes('/')) {
    const [fq, nq] = entry.folder.split('/');
    const f = matchFolder(await folders('note'), fq);
    if (!f) return reply(env, chat, `⚠️ Folder "${fq}" tidak ketemu (atau lebih dari satu yang cocok).`);
    const notes = records(await fb('notes')).filter((n) => n.folderId === f.id);
    const note = matchFolder(notes.map((n) => ({ ...n, name: n.title ?? '' })), nq);
    if (!note) {
      const daftar = notes.map((n) => `• ${n.title}`).join('\n') || '(kosong)';
      return reply(env, chat, `⚠️ Catatan "${nq}" tidak ketemu di ${f.name}. Isinya:\n${daftar}`);
    }
    return reply(env, chat, await appendNote(chat, note, entry.text));
  }

  const state = entry.folder ? null : await fb(`bot_state/${chat}`);

  // Catatan aktif dipilih -> tambahkan ke isi catatan itu.
  if (entry.kind === 'note' && state?.noteId) {
    const note = await fb(`notes/${state.noteId}`);
    if (note) return reply(env, chat, await appendNote(chat, note, entry.text));
  }

  const list = await folders(entry.kind);
  if (!list.length) return reply(env, chat, '⚠️ Belum ada folder. Buat folder dulu di aplikasi.');

  // @folder di pesan > folder aktif (dari /folder) > tanya lewat tombol.
  const active = state?.[entry.kind];
  const target = matchFolder(list, entry.folder) ?? list.find((f) => f.id === active);
  if (target) return reply(env, chat, await save(chat, entry, target));

  // Simpan sementara, lalu tanya folder lewat tombol.
  // Node "bot_pending" diabaikan oleh app (bukan tabel yang disinkron).
  await fb(`bot_pending/${chat}`, 'PUT', entry);
  const rows = grid(list.map((f) => ({ text: f.name, callback_data: `f:${f.id}` })));
  rows.push([{ text: '✖️ Batal', callback_data: 'cancel' }]);
  return reply(env, chat, entry.folder ? `Folder "@${entry.folder}" tidak ketemu. Pilih:` : 'Masuk ke folder mana?', {
    reply_markup: { inline_keyboard: rows },
  });
}

async function onButton(q, env) {
  const chat = q.message.chat.id;
  const edit = (text) => tg(env, 'editMessageText', { chat_id: chat, message_id: q.message.message_id, text });
  await tg(env, 'answerCallbackQuery', { callback_query_id: q.id });
  if (String(q.from.id) !== env.ALLOWED_ID) return;

  const menu = (text, buttons) => tg(env, 'editMessageText', {
    chat_id: chat, message_id: q.message.message_id, text, reply_markup: { inline_keyboard: buttons },
  });
  const state = (await fb(`bot_state/${chat}`)) ?? {};
  const setState = (patch) => fb(`bot_state/${chat}`, 'PATCH', patch);

  // Alur /folder:
  //   l:<kind>        -> daftar folder
  //   a:kas:<id>      -> folder usaha aktif
  //   a:note:<id>     -> daftar catatan di folder itu
  //   n:<folder>:<id> -> catatan aktif (#catat ditambahkan ke isinya)
  //   nf:<folder>     -> tiap #catat jadi catatan baru di folder itu
  if (q.data.startsWith('l:')) {
    const kind = q.data.slice(2);
    const list = await folders(kind);
    if (!list.length) return edit('⚠️ Belum ada folder. Buat dulu di aplikasi.');
    return menu('Pilih folder (✅ = aktif sekarang):', grid(list.map((f) => ({
      text: (f.id === state[kind] ? '✅ ' : '') + f.name,
      callback_data: `a:${kind}:${f.id}`,
    }))));
  }
  if (q.data.startsWith('a:')) {
    const [, kind, idStr] = q.data.split(':');
    const f = (await folders(kind)).find((x) => x.id === Number(idStr));
    if (!f) return edit('⚠️ Folder sudah tidak ada.');
    if (kind === 'kas') {
      await setState({ kas: f.id });
      return edit(`✅ Folder Usaha aktif: ${f.name}\nSemua #keluar / #masuk masuk ke sini.\nGanti: /folder`);
    }
    const notes = records(await fb('notes')).filter((n) => n.folderId === f.id);
    const buttons = notes.map((n) => [{
      text: (n.id === state.noteId ? '✅ ' : '') + (n.title || '(tanpa judul)').slice(0, 40),
      callback_data: `n:${f.id}:${n.id}`,
    }]);
    buttons.push([{ text: '➕ Tiap #catat jadi catatan baru', callback_data: `nf:${f.id}` }]);
    return menu(`📂 ${f.name}\nPilih catatan yang mau ditambah isinya:`, buttons);
  }
  if (q.data.startsWith('n:')) {
    const [, folderId, noteId] = q.data.split(':').map(Number);
    const note = await fb(`notes/${noteId}`);
    if (!note) return edit('⚠️ Catatan sudah tidak ada.');
    await setState({ note: folderId, noteId });
    return edit(`✅ Catatan aktif: "${note.title}"\nSetiap #catat akan ditambahkan ke isinya.\nGanti: /folder`);
  }
  if (q.data.startsWith('nf:')) {
    const folderId = Number(q.data.slice(3));
    const f = (await folders('note')).find((x) => x.id === folderId);
    if (!f) return edit('⚠️ Folder sudah tidak ada.');
    await setState({ note: folderId, noteId: null });
    return edit(`✅ Folder Catatan aktif: ${f.name}\nSetiap #catat jadi catatan baru (baris pertama = judul).\nGanti: /folder`);
  }

  const entry = await fb(`bot_pending/${chat}`);
  await fb(`bot_pending/${chat}`, 'DELETE');
  if (q.data === 'cancel') return edit('Dibatalkan.');
  if (!entry) return edit('⚠️ Data sudah kedaluwarsa, kirim ulang pesannya.');

  const id = Number(q.data.slice(2));
  const target = (await folders(entry.kind)).find((f) => f.id === id);
  if (!target) return edit('⚠️ Folder sudah tidak ada.');
  return edit(await save(chat, entry, target));
}

// ---------- Laporan ----------

const BULAN = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
/** "8", "agustus", "agu", "lalu", "8/2025", "agustus 2025" -> yyyy-MM, selain itu null. */
export function parseBulan(s) {
  s = s.toLowerCase().trim();
  const now = today();
  if (s === 'lalu' || s === 'kemarin') {
    const [y, m] = now.split('-').map(Number);
    return m === 1 ? `${y - 1}-12` : `${y}-${String(m - 1).padStart(2, '0')}`;
  }
  const mt = /^([a-z]+|\d{1,2})(?:[\s/-]+(\d{4}|\d{2}))?$/.exec(s);
  if (!mt) return null;
  const m = /^\d+$/.test(mt[1]) ? Number(mt[1]) : BULAN.findIndex((b) => mt[1].length >= 3 && b.toLowerCase().startsWith(mt[1])) + 1;
  if (m < 1 || m > 12) return null;
  const y = mt[2] ? (mt[2].length === 2 ? '20' + mt[2] : mt[2]) : now.slice(0, 4);
  return `${y}-${String(m).padStart(2, '0')}`;
}

const tglIndo = (iso) => `${Number(iso.slice(8, 10))} ${BULAN[Number(iso.slice(5, 7)) - 1]} ${iso.slice(0, 4)}`;

/** Transaksi usaha yang tanggalnya diawali [prefix] (yyyy-MM-dd atau yyyy-MM). */
async function kasDengan(prefix, only) {
  const [kas, list] = await Promise.all([fb('usaha_kas'), folders('kas')]);
  const nama = Object.fromEntries(list.map((f) => [f.id, f.name]));
  return records(kas)
    // Transaksi yang foldernya sudah dihapus tidak tampil di app, jadi dilewati juga.
    .filter((k) => nama[k.folder_id] && String(k.tanggal).startsWith(prefix) && (!only || k.folder_id === only.id))
    .map((k) => ({ ...k, nominal: Number(k.nominal), folder: nama[k.folder_id] }));
}

function totals(rows) {
  const masuk = rows.filter((k) => k.tipe === 'Pemasukan').reduce((a, k) => a + k.nominal, 0);
  const keluar = rows.filter((k) => k.tipe === 'Pengeluaran').reduce((a, k) => a + k.nominal, 0);
  return `🟢 Masuk   ${rupiah(masuk)}\n🔴 Keluar  ${rupiah(keluar)}\n💰 Selisih ${rupiah(masuk - keluar)}`;
}

async function laporanHari(only, iso = today()) {
  const rows = await kasDengan(iso, only);
  const head = `📅 ${tglIndo(iso)}${only ? ` · ${only.name}` : ''}`;
  if (!rows.length) return `${head}\nBelum ada transaksi.`;
  // Batasi daftar supaya tidak melewati batas panjang pesan Telegram.
  const list = rows.slice(0, 40).map((k) =>
    `${k.tipe === 'Pemasukan' ? '🟢' : '🔴'} ${rupiah(k.nominal)} ${k.keterangan}${only ? '' : ` · ${k.folder}`}`);
  if (rows.length > 40) list.push(`… dan ${rows.length - 40} lainnya`);
  return `${head}\n\n${list.join('\n')}\n━━━━━━━━━━\n${totals(rows)}`;
}

async function laporanBulan(ym, only) {
  const rows = await kasDengan(ym, only);
  const head = `🗓️ ${BULAN[Number(ym.slice(5, 7)) - 1]} ${ym.slice(0, 4)}${only ? ` · ${only.name}` : ''}`;
  if (!rows.length) return `${head}\nBelum ada transaksi.`;
  const parts = [head, totals(rows)];
  if (!only) {
    const per = {};
    for (const k of rows) per[k.folder] = (per[k.folder] ?? 0) + (k.tipe === 'Pemasukan' ? k.nominal : -k.nominal);
    parts.push('📂 Selisih per folder:\n' + Object.entries(per).map(([f, v]) => `• ${f}: ${rupiah(v)}`).join('\n'));
  }
  const top = rows.filter((k) => k.tipe === 'Pengeluaran').sort((a, b) => b.nominal - a.nominal).slice(0, 5);
  if (top.length) {
    parts.push('🔝 Pengeluaran terbesar:\n' + top.map((k, i) =>
      `${i + 1}. ${rupiah(k.nominal)} ${k.keterangan} (${Number(k.tanggal.slice(8, 10))}/${Number(k.tanggal.slice(5, 7))})`).join('\n'));
  }
  return parts.join('\n\n');
}

/** Saldo (semua waktu) per folder usaha di [pick]. */
/** [ringkas]: 1 baris per folder, folder tanpa transaksi dilewati. */
async function saldoText(pick, ringkas = false) {
  if (!pick.length) return '⚠️ Belum ada folder usaha.';
  const kas = records(await fb('usaha_kas'));
  const sum = (fid, tipe) => kas.filter((k) => k.folder_id === fid && k.tipe === tipe).reduce((a, k) => a + Number(k.nominal), 0);
  let all = 0;
  const lines = [];
  for (const f of pick) {
    const masuk = sum(f.id, 'Pemasukan');
    const keluar = sum(f.id, 'Pengeluaran');
    all += masuk - keluar;
    if (!ringkas) lines.push(`📂 ${f.name}\n🟢 Masuk  ${rupiah(masuk)}\n🔴 Keluar ${rupiah(keluar)}\n💰 Saldo  ${rupiah(masuk - keluar)}`);
    else if (masuk || keluar) lines.push(`• ${f.name}: ${rupiah(masuk - keluar)}`);
  }
  if (pick.length > 1) lines.push(`━━━━━━━━━━\n💰 Total semua: ${rupiah(all)}`);
  return lines.join(ringkas ? '\n' : '\n\n');
}

/** [n] catatan terbaru (id terbesar = paling baru dibuat). */
async function catatanTerbaru(n = 5) {
  const [notes, list] = await Promise.all([fb('notes'), folders('note')]);
  const nama = Object.fromEntries(list.map((f) => [f.id, f.name]));
  const latest = records(notes).filter((x) => nama[x.folderId]).sort((a, b) => b.id - a.id).slice(0, n);
  if (!latest.length) return '📝 Belum ada catatan.';
  return '📝 Catatan terbaru:\n\n' + latest.map((x) => {
    const isi = (x.content ?? '').replace(/\s+/g, ' ').trim();
    return `• ${x.title || '(tanpa judul)'} · ${nama[x.folderId]}${isi ? `\n  ${isi.length > 80 ? isi.slice(0, 80) + '…' : isi}` : ''}`;
  }).join('\n');
}

/** Cron 06.00 WIB: kemarin + saldo semua folder usaha + catatan terbaru; rekap bulan lalu tiap tanggal 1. */
async function laporanPagi(env) {
  const chat = env.ALLOWED_ID; // chat pribadi: chat id = user id
  await reply(env, chat, `☀️ Selamat pagi! Laporan kemarin:\n\n${await laporanHari(null, today(-1))}`);
  await reply(env, chat, `💼 Saldo semua folder usaha:\n\n${await saldoText(await folders('kas'), true)}\n\nDetail: /saldo semua`);
  await reply(env, chat, await catatanTerbaru());
  if (today().endsWith('-01')) {
    await reply(env, chat, `📊 Rekap bulan lalu\n\n${await laporanBulan(today(-1).slice(0, 7), null)}`);
  }
}

/** Cron tiap 3 jam (09-21 WIB): ingatkan input hari ini. */
async function pengingat(env) {
  const rows = await kasDengan(today(), null);
  const jam = new Date(Date.now() + 7 * 3600e3).getUTCHours(); // jam WIB
  let text;
  if (!rows.length) {
    text = '⏰ Belum ada transaksi hari ini.\nAda pengeluaran/pemasukan yang belum dicatat?\nContoh: #keluar 15rb parkir';
  } else {
    const masuk = rows.filter((k) => k.tipe === 'Pemasukan').reduce((a, k) => a + k.nominal, 0);
    const keluar = rows.filter((k) => k.tipe === 'Pengeluaran').reduce((a, k) => a + k.nominal, 0);
    text = `⏰ Sudah ${rows.length} transaksi hari ini\n🟢 ${rupiah(masuk)} · 🔴 ${rupiah(keluar)}\nAda yang belum dicatat? Detail: /hariini`;
  }
  if (jam >= 21) text += '\n\n🌙 Besok jam 06.00 laporan lengkap dikirim.';
  await reply(env, env.ALLOWED_ID, text);
}

/** Ingat input terakhir supaya bisa dibatalkan lewat /hapus. */
const remember = (chat, last) => fb(`bot_state/${chat}/last`, 'PUT', last);

async function appendNote(chat, note, text) {
  const content = note.content ? `${note.content}\n${text}` : text;
  await fb(`notes/${note.id}`, 'PATCH', { content });
  await remember(chat, { type: 'append', id: note.id, prev: note.content ?? '', label: `"${text}" di "${note.title}"` });
  return `📝 Ditambahkan ke "${note.title}"\nSalah? /hapus`;
}

/** /hapus: batalkan satu input terakhir dari bot. */
async function undo(chat) {
  const last = await fb(`bot_state/${chat}/last`);
  if (!last) return '⚠️ Tidak ada input terakhir yang bisa dibatalkan.';
  if (last.type === 'append') await fb(`notes/${last.id}`, 'PATCH', { content: last.prev });
  else await fb(`${last.type}/${last.id}`, 'DELETE');
  await fb(`bot_state/${chat}/last`, 'DELETE');
  return `🗑️ Dibatalkan: ${last.label}`;
}

/** Tulis ke Firebase. Kolom HARUS sama persis dengan tabel SQLite di app. */
async function save(chat, entry, folder) {
  // Timestamp sebagai id: tidak bentrok dengan id autoincrement dari HP.
  const id = Date.now();
  if (entry.kind === 'kas') {
    await fb(`usaha_kas/${id}`, 'PUT', {
      id,
      folder_id: folder.id,
      tanggal: entry.tanggal,
      keterangan: entry.keterangan,
      nominal: entry.nominal,
      tipe: entry.tipe,
    });
    const label = `${entry.tipe} ${rupiah(entry.nominal)} "${entry.keterangan}" → ${folder.name}`;
    await remember(chat, { type: 'usaha_kas', id, label });
    const tgl = entry.tanggal === today() ? '' : ` (${entry.tanggal})`;
    return `${entry.tipe === 'Pemasukan' ? '🟢' : '🔴'} ${label}${tgl}\nSalah? /hapus`;
  }
  await fb(`notes/${id}`, 'PUT', { id, title: entry.title, content: entry.content, folderId: folder.id });
  await remember(chat, { type: 'notes', id, label: `catatan "${entry.title}"` });
  return `📝 Catatan "${entry.title}" → ${folder.name}\nSalah? /hapus`;
}

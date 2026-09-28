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

/** Tanggal hari ini (WIB) format yyyy-MM-dd, sama dengan app. */
const today = () => new Date(Date.now() + 7 * 3600e3).toISOString().slice(0, 10);

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
      'Saldo:\n/saldo = folder aktif\n/saldo @toko\n/saldo semua');
  }

  if (cmd === '/folder') return reply(env, chat, 'Pilih jenis folder yang mau diaktifkan:', {
    reply_markup: { inline_keyboard: [[
      { text: '💰 Folder Usaha', callback_data: 'l:kas' },
      { text: '📝 Folder Catatan', callback_data: 'l:note' },
    ]] },
  });

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
    const kas = records(await fb('usaha_kas'));
    const sum = (fid, tipe) => kas.filter((k) => k.folder_id === fid && k.tipe === tipe).reduce((a, k) => a + Number(k.nominal), 0);
    let all = 0;
    const lines = pick.map((f) => {
      const masuk = sum(f.id, 'Pemasukan');
      const keluar = sum(f.id, 'Pengeluaran');
      all += masuk - keluar;
      return `📂 ${f.name}\n🟢 Masuk  ${rupiah(masuk)}\n🔴 Keluar ${rupiah(keluar)}\n💰 Saldo  ${rupiah(masuk - keluar)}`;
    });
    if (pick.length > 1) lines.push(`━━━━━━━━━━\n💰 Total semua: ${rupiah(all)}`);
    return reply(env, chat, lines.join('\n\n') || '⚠️ Belum ada folder usaha.');
  }

  let entry;
  const c = cmd.toLowerCase();
  if (c === '#keluar' || c === '#masuk') {
    const { folder, rest } = takeFolder(words.join(' '));
    const [nom, ...ket] = rest.split(/\s+/);
    const nominal = parseNominal(nom ?? '');
    if (!nominal) return reply(env, chat, '⚠️ Nominal tidak valid. Contoh: #keluar 50000 bensin');
    entry = {
      kind: 'kas',
      folder,
      tipe: c === '#masuk' ? 'Pemasukan' : 'Pengeluaran',
      nominal,
      keterangan: ket.join(' ') || '-',
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
    const content = note.content ? `${note.content}\n${entry.text}` : entry.text;
    await fb(`notes/${note.id}`, 'PATCH', { content });
    return reply(env, chat, `📝 Ditambahkan ke "${note.title}" (${f.name})`);
  }

  const state = entry.folder ? null : await fb(`bot_state/${chat}`);

  // Catatan aktif dipilih -> tambahkan ke isi catatan itu.
  if (entry.kind === 'note' && state?.noteId) {
    const note = await fb(`notes/${state.noteId}`);
    if (note) {
      const content = note.content ? `${note.content}\n${entry.text}` : entry.text;
      await fb(`notes/${state.noteId}`, 'PATCH', { content });
      return reply(env, chat, `📝 Ditambahkan ke "${note.title}"`);
    }
  }

  const list = await folders(entry.kind);
  if (!list.length) return reply(env, chat, '⚠️ Belum ada folder. Buat folder dulu di aplikasi.');

  // @folder di pesan > folder aktif (dari /folder) > tanya lewat tombol.
  const active = state?.[entry.kind];
  const target = matchFolder(list, entry.folder) ?? list.find((f) => f.id === active);
  if (target) return reply(env, chat, await save(entry, target));

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
  return edit(await save(entry, target));
}

/** Tulis ke Firebase. Kolom HARUS sama persis dengan tabel SQLite di app. */
async function save(entry, folder) {
  // Timestamp sebagai id: tidak bentrok dengan id autoincrement dari HP.
  const id = Date.now();
  if (entry.kind === 'kas') {
    await fb(`usaha_kas/${id}`, 'PUT', {
      id,
      folder_id: folder.id,
      tanggal: today(),
      keterangan: entry.keterangan,
      nominal: entry.nominal,
      tipe: entry.tipe,
    });
    const icon = entry.tipe === 'Pemasukan' ? '🟢' : '🔴';
    return `${icon} ${entry.tipe} ${rupiah(entry.nominal)} "${entry.keterangan}" → ${folder.name}`;
  }
  await fb(`notes/${id}`, 'PUT', { id, title: entry.title, content: entry.content, folderId: folder.id });
  return `📝 Catatan "${entry.title}" → ${folder.name}`;
}

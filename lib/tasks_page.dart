import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'models.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  List<Task> tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    tasks = await DatabaseHelper.instance.getTasks();
    setState(() {});
  }

  void _addTask() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Tugas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: titleController,
                decoration: const InputDecoration(hintText: 'Judul')),
            TextField(
                controller: descController,
                decoration: const InputDecoration(hintText: 'Deskripsi')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                await DatabaseHelper.instance.insertTask(
                  Task(
                      title: titleController.text,
                      description: descController.text),
                );
                Navigator.pop(context);
                _loadTasks();
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _toggleDone(Task task) async {
    await DatabaseHelper.instance.updateTask(
      Task(
          id: task.id,
          title: task.title,
          description: task.description,
          isDone: !task.isDone),
    );
    _loadTasks();
  }

  void _deleteTask(int id) async {
    await DatabaseHelper.instance.deleteTask(id);
    _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5E4), // Cream background
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        backgroundColor: const Color(0xFFF4B41A),
        foregroundColor: const Color(0xFF143D59),
        elevation: 7,
        child: const Icon(Icons.add, size: 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        tooltip: 'Tambah Tugas',
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFFF4B41A), size: 30),
                const SizedBox(width: 5),
                const Text(
                  'Daftar Tugas',
                  style: TextStyle(
                    color: Color(0xFF143D59),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Text(
                      'Belum ada tugas',
                      style: TextStyle(color: Color(0xFFB0A295), fontSize: 18),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: tasks.length,
                    separatorBuilder: (context, i) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final task = tasks[i];
                      return Card(
                        color: Colors.white,
                        elevation: 4,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          leading: GestureDetector(
                            onTap: () => _toggleDone(task),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: task.isDone ? Color(0xFFF4B41A) : Colors.transparent,
                                border: Border.all(
                                  color: Color(0xFFF4B41A),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: task.isDone
                                  ? const Icon(Icons.check, size: 18, color: Color(0xFF143D59))
                                  : null,
                            ),
                          ),
                          title: Text(
                            task.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Color(0xFF143D59),
                              decoration: task.isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  task.description,
                                  style: TextStyle(
                                    color: Color(0xFFB0A295),
                                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                              if (task.isDone)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFB0E57C),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Selesai',
                                    style: TextStyle(
                                      color: Color(0xFF143D59),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF4B41A).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Belum',
                                    style: TextStyle(
                                      color: Color(0xFF143D59),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Color(0xFFF4B41A)),
                            onPressed: () => _deleteTask(task.id!),
                            tooltip: 'Hapus',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

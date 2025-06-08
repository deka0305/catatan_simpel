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
      appBar: AppBar(
        backgroundColor: const Color(0xFF143D59), // Navy blue
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Tugas'),
      ),
      body: Column(
        children: [
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Text(
                      'Belum ada tugas',
                      style: TextStyle(color: Color(0xFFB0A295), fontSize: 18),
                    ),
                  )
                : ListView.separated(
                    itemCount: tasks.length,
                    separatorBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(
                        color: Color(0xFFF4B41A), // Yellow
                        thickness: 1.2,
                        height: 8,
                      ),
                    ),
                    itemBuilder: (context, i) {
                      final task = tasks[i];
                      return Card(
                        color: Color(0xFFFFF5E4), // Cream background
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          title: Text(
                            task.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Color(0xFF143D59), // Navy blue
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            task.description,
                            style: TextStyle(
                              color: Color(0xFFB0A295),
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          leading: Checkbox(
                            value: task.isDone,
                            onChanged: (_) => _toggleDone(task),
                            activeColor: Color(0xFFF4B41A), // Yellow
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete,
                                color: Color(0xFFF4B41A)),
                            onPressed: () => _deleteTask(task.id!),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FloatingActionButton.extended(
              onPressed: _addTask,
              label: const Text('Tambah Tugas'),
              icon: const Icon(Icons.add_task),
              backgroundColor: Color(0xFFF4B41A), // Yellow
              foregroundColor: Color(0xFF143D59), // Navy blue
            ),
          ),
        ],
      ),
      // bottomNavigationBar: BottomAppBar(
      // color: const Color(0xFF143D59), // Navy blue
      // child: SizedBox(height: 56),
      // ),
    );
  }
}

import 'package:dynamic_routes/dynamic_routes/mixins/participator.dart';
import 'package:flutter/material.dart';

class ParticipatorPage extends StatefulWidget {
  final String title;
  final Color backgroundColor;
  final int? withPopFor;

  const ParticipatorPage(
      {this.backgroundColor = Colors.white,
      required this.title,
      this.withPopFor,
      Key? key})
      : super(key: key);

  @override
  State<ParticipatorPage> createState() => _ParticipatorPageState();
}

class _ParticipatorPageState extends State<ParticipatorPage>
    with DynamicRoutesParticipator {
  @override
  Widget build(BuildContext context) {
    final value = dynamicRoutesParticipator.getCache();
    return Scaffold(
      appBar: widget.withPopFor != null
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => dynamicRoutesParticipator.popFor(
                    context, widget.withPopFor!),
              ),
              title: Text("Pop for: ${widget.withPopFor}"),
              centerTitle: true,
            )
          : null,
      floatingActionButton: ElevatedButton(
          child: Text("Increment Cached Value: $value"),
          onPressed: () {
            dynamicRoutesParticipator.setCache(value + 1);
            setState(() {});
          }),
      backgroundColor: widget.backgroundColor,
      body: Align(
          child: Text(widget.title, style: const TextStyle(fontSize: 30))),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: TextButton(
          key: Key(widget.title),
          onPressed: () =>
              dynamicRoutesParticipator.pushNext(context).then((_) {
            setState(() {});
          }),
          child: const Text("Next Page"),
        ),
      ),
    );
  }
}

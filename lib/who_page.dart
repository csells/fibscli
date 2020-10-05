import 'package:fibscli/fibs_state.dart';
import 'package:fibscli/main.dart';
import 'package:fibscli/tinystate.dart';
import 'package:flutter/material.dart';

class WhoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(App.title)),
        body: ChangeNotifierBuilder<NotifierList<WhoInfo>>(
          notifier: App.fibsState.whoInfos,
          build: (context, whoInfos, child) => DataTable(
            columns: [
              DataColumn(label: Text('user')),
              DataColumn(label: Text('away')),
              DataColumn(label: Text('experience')),
              DataColumn(label: Text('opponent')),
              DataColumn(label: Text('rating')),
              DataColumn(label: Text('ready')),
              DataColumn(label: Text('watching')),
            ],
            rows: [
              for (final whoInfo in whoInfos)
                DataRow(
                  cells: [
                    DataCell(Text(whoInfo.user)),
                    DataCell(Text(whoInfo.away.toString())),
                    DataCell(Text(whoInfo.experience.toString())),
                    DataCell(Text(whoInfo.opponent)),
                    DataCell(Text(whoInfo.rating.toStringAsFixed(2))),
                    DataCell(Text(whoInfo.ready.toString())),
                    DataCell(Text(whoInfo.watching)),
                  ],
                ),
            ],
          ),
        ),
      );
}

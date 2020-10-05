import 'package:fibscli/fibs_state.dart';
import 'package:fibscli/main.dart';
import 'package:fibscli/tinystate.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class WhoPage extends StatefulWidget {
  @override
  _WhoPageState createState() => _WhoPageState();
}

class _WhoPageState extends State<WhoPage> {
  var _source = WhoDataSource(App.fibs.whoInfos, filter: 'both');
  WhoInfo _selected;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(App.title),
          actions: [OutlineButton(onPressed: () => App.fibs.logout(), child: Text('Logout'))],
        ),
        body: Stack(
          children: [
            ChangeNotifierBuilder<NotifierList<WhoInfo>>(
              notifier: App.fibs.whoInfos,
              builder: (context, whoInfos, child) => Column(
                children: [
                  Container(
                    alignment: Alignment.center,
                    padding: EdgeInsets.all(10),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            'FIBS Who',
                            style: TextStyle(
                                color: Theme.of(context).primaryColor, fontWeight: FontWeight.w500, fontSize: 36),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: DropdownButton<String>(
                            value: _source.filter,
                            items: [
                              for (final item in ['both', 'humans', 'bots'])
                                DropdownMenuItem<String>(value: item, child: Text(item)),
                            ],
                            onChanged: (item) => setState(() => _source.filter = item),
                          ),
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: SfDataGrid(
                      source: _source,
                      columnWidthMode: ColumnWidthMode.fill,
                      allowMultiColumnSorting: true,
                      allowSorting: true,
                      allowTriStateSorting: true,
                      selectionMode: SelectionMode.singleDeselect,
                      onSelectionChanged: _selChanged,
                      columns: <GridColumn>[
                        GridTextColumn(mappingName: 'user', headerText: 'user'),
                        GridNumericColumn(mappingName: 'experience', headerText: 'experiece'),
                        GridTextColumn(mappingName: 'opponent', headerText: 'opponent'),
                        GridNumericColumn(mappingName: 'rating', headerText: 'rating'),
                        GridTextColumn(mappingName: 'ready', headerText: 'ready'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_selected != null)
              Align(
                alignment: Alignment.topRight,
                child: Drawer(
                  child: Column(
                    children: [
                      Table(
                        border: TableBorder.all(),
                        children: [
                          TableRow(children: [Text('user'), Text(_selected.user)]),
                          TableRow(children: [Text('away'), Text(_selected.away.toString())]),
                          TableRow(children: [Text('client'), Text(_selected.client)]),
                          TableRow(children: [Text('email'), Text(_selected.email)]),
                          TableRow(children: [Text('experience'), Text(_selected.experience.toString())]),
                          TableRow(children: [Text('hostname'), Text(_selected.hostname)]),
                          TableRow(children: [Text('last active'), Text(_selected.lastActive.toString())]),
                          TableRow(children: [Text('last login'), Text(_selected.lastLogin.toString())]),
                          TableRow(children: [Text('opponent'), Text(_selected.opponent)]),
                          TableRow(children: [Text('rating'), Text(_selected.rating.toStringAsFixed(2))]),
                          TableRow(children: [Text('ready'), Text(_selected.ready.toString())]),
                          TableRow(children: [Text('watching'), Text(_selected.watching)]),
                        ],
                      ),
                      if (_selected.user != App.fibs.user && _selected.opponent.isNotEmpty)
                        OutlineButton(
                          onPressed: () => _watch(_selected),
                          child: Text('Watch'),
                        ),
                      if (_selected.user != App.fibs.user && _selected.opponent.isEmpty && _selected.ready)
                        OutlineButton(
                          onPressed: () => _play(_selected),
                          child: Text('Play'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );

  void _selChanged(List<Object> addedRows, List<Object> removedRows) {
    if (removedRows.isNotEmpty && identical(removedRows.single, _selected)) _selected = null;
    if (addedRows.isNotEmpty) _selected = addedRows.single;
    setState(() {});
  }

  void _watch(WhoInfo who) {
    assert(who != null);
    print(who.user);
  }

  void _play(WhoInfo who) {
    assert(who != null);
    print(who.user);
  }
}

class WhoDataSource extends DataGridSource<WhoInfo> {
  final NotifierList<WhoInfo> whoInfos;
  String _filter;
  WhoDataSource(this.whoInfos, {String filter = 'both'})
      : _filter = filter,
        assert(whoInfos != null) {
    whoInfos.addListener(notifyDataSourceListeners);
  }

  @override
  void dispose() {
    whoInfos.removeListener(notifyDataSourceListeners);
    super.dispose();
  }

  String get filter => _filter;
  set filter(String filter) {
    _filter = filter;
    notifyDataSourceListeners();
  }

  static List<WhoInfo> _filtered(NotifierList<WhoInfo> whoInfos, String filter) {
    bool bot(String user) => user.contains('Bot');

    switch (filter) {
      case 'both':
        return whoInfos.toList();
      case 'humans':
        return whoInfos.where((wi) => !bot(wi.user)).toList();
      case 'bots':
        return whoInfos.where((wi) => bot(wi.user)).toList();
      default:
        throw 'unreachable: filter= $filter';
    }
  }

  @override
  List<WhoInfo> get dataSource => _filtered(whoInfos, _filter);

  @override
  Object getValue(WhoInfo whoInfo, String columnName) {
    switch (columnName) {
      case 'user':
        return whoInfo.user;
      case 'away':
        return whoInfo.away.toString();
      case 'experience':
        return whoInfo.experience;
      case 'opponent':
        return whoInfo.opponent;
      case 'rating':
        return whoInfo.rating;
      case 'ready':
        return whoInfo.ready.toString();
      default:
        throw 'unreachable: columnName= $columnName';
    }
  }
}

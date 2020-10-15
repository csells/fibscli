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
  var _showMessages = false;
  var _source = WhoDataSource(App.fibs.whoInfos, filter: 'both');

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(App.title),
          actions: [
            IconButton(
              onPressed: () => setState(() => _showMessages = !_showMessages),
              icon: Icon(Icons.message),
              tooltip: _showMessages ? 'hide messages' : 'show messages',
            ),
            OutlineButton(onPressed: () => App.fibs.logout(), child: Text('Logout')),
          ],
        ),
        body: Row(
          children: [
            Expanded(
              child: Stack(
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
                              Align(
                                alignment: Alignment.centerLeft,
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
                            onCellTap: _tapCell,
                            columns: <GridColumn>[
                              GridTextColumn(mappingName: 'user', headerText: 'user'),
                              GridNumericColumn(mappingName: 'experience', headerText: 'experience'),
                              GridTextColumn(mappingName: 'opponent', headerText: 'opponent'),
                              GridNumericColumn(mappingName: 'rating', headerText: 'rating'),
                              GridTextColumn(mappingName: 'ready', headerText: 'ready'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_showMessages) MessagesView(),
          ],
        ),
      );

  void _watch(WhoInfo who) {
    assert(who != null);
    print('TODO: watch ${who.user}');
  }

  void _play(WhoInfo who) {
    assert(who != null);
    print('TODO: play ${who.user}');
  }

  void _tapWho(BuildContext context, WhoInfo who) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Who Info'),
        actions: [
          OutlineButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Close'),
          ),
          if (who.user != App.fibs.user && who.opponent.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _watch(who);
              },
              child: Text('Watch'),
            ),
          if (who.user != App.fibs.user && who.opponent.isEmpty && who.ready)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _play(who);
              },
              child: Text('Play'),
            ),
        ],
        content: Container(
          width: 500,
          child: Table(
            columnWidths: {0: FixedColumnWidth(100)},
            children: [
              TableRow(children: [Text('user'), Text(who.user)]),
              TableRow(children: [Text('away'), Text(who.away.toString())]),
              TableRow(children: [Text('client'), Text(who.client)]),
              TableRow(children: [Text('email'), Text(who.email)]),
              TableRow(children: [Text('experience'), Text(who.experience.toString())]),
              TableRow(children: [Text('hostname'), Text(who.hostname)]),
              TableRow(children: [Text('last active'), Text(who.lastActive.toString())]),
              TableRow(children: [Text('last login'), Text(who.lastLogin.toString())]),
              TableRow(children: [Text('opponent'), Text(who.opponent)]),
              TableRow(children: [Text('rating'), Text(who.rating.toStringAsFixed(2))]),
              TableRow(children: [Text('ready'), Text(who.ready.toString())]),
              TableRow(children: [Text('watching'), Text(who.watching)]),
            ],
          ),
        ),
      ),
    );
  }

  void _tapCell(DataGridCellTapDetails details) {
    if (details.rowColumnIndex.rowIndex == 0) return; // header
    final who = _source.getCellValue(details.rowColumnIndex.rowIndex - 1, '') as WhoInfo;
    _tapWho(context, who);
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
      case '':
        return whoInfo;
      default:
        throw 'unreachable: columnName= $columnName';
    }
  }

  @override
  int compare(WhoInfo a, WhoInfo b, SortColumnDetails sortColumn) => sortColumn.name == 'user'
      ? sortColumn.sortDirection == DataGridSortDirection.ascending
          ? a.user.toLowerCase().compareTo(b.user.toLowerCase())
          : b.user.toLowerCase().compareTo(a.user.toLowerCase())
      : super.compare(a, b, sortColumn);
}

class MessagesView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 400,
        decoration: BoxDecoration(border: Border.all(width: 1, color: Color.fromRGBO(0, 0, 0, 0.26))),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'FIBS Messages',
                  style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w500, fontSize: 36),
                ),
              ),
            ),
            Expanded(
              child: ChangeNotifierBuilder<NotifierList<FibsMessage>>(
                notifier: App.fibs.messages,
                builder: (context, messages, child) => ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) => index >= messages.length
                      ? null
                      : ListTile(
                          key: ValueKey(index),
                          title: Text(messages[index].toString()),
                        ),
                ),
              ),
            ),
          ],
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import 'package:fibscli/fibs_state.dart';
import 'package:fibscli/main.dart';
import 'package:fibscli/tinystate.dart';

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
            IconButton(
              onPressed: App.fibs.connected ? () => _tapSend(context) : null,
              icon: Icon(Icons.send),
              tooltip: 'send command',
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
            // if (_showMessages) MessagesView(whoInfos: App.fibs.whoInfos),
          ],
        ),
      );

  void _watch(WhoInfo who) {
    assert(who != null);
    print('TODO: watch ${who.user}');
  }

  void _invite(WhoInfo who) {
    assert(who != null);
    App.fibs.invite(who, 1);
  }

  void _tapWho(BuildContext context, WhoInfo who) async {
    await showDialog<void>(
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
                _invite(who);
              },
              child: Text('Invite'),
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

  void _tapSend(BuildContext context) async {
    final cmd = await SendComandDialog.getCommand(context);
    if (cmd != null && cmd.isNotEmpty) App.fibs.send(cmd);
  }
}

class SendComandDialog extends StatefulWidget {
  static Future<String> getCommand(BuildContext context) async => await showDialog<String>(
        context: context,
        builder: (context) => Dialog(child: SendComandDialog()),
      );

  @override
  _SendComandDialogState createState() => new _SendComandDialogState();
}

class _SendComandDialogState extends State<SendComandDialog> {
  TextEditingController _controller;

  @override
  initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
                child: TextField(decoration: InputDecoration(hintText: "command to send"), controller: _controller)),
            OutlineButton(onPressed: () => Navigator.pop(context, ''), child: Text('Cancel')),
            SizedBox(width: 8),
            ElevatedButton(onPressed: () => Navigator.pop(context, _controller.text), child: Text('Send')),
          ],
        ),
      );
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

/*
enum UserState { none, playing, watching }

class MessagesView extends StatefulWidget {
  final NotifierList<WhoInfo> whoInfos;
  final WhoInfo user;
  final UserState userState;
  const MessagesView({
    @required this.whoInfos,
    @required this.user,
    @required this.userState,
  });

  @override
  _MessagesViewState createState() => _MessagesViewState();
}

/// shows the options for sending messages based on the state of player, not playing or watching, playing, watching,
/// command                   who can hear                  when can do           state of <user>
/// shout <message>           everyone                      anytime               n/a
/// say <message>             opponent (+ watchers?)        playing               n/a
/// kibitz <message>          players + watchers            playing or watching   n/a
/// whisper <message>         watchers                      playing or watching   n/a
/// tell <user> <message>     <user>                        anytime               logged in
/// message <user> <message>  <user>                        anytime               logged in or not (queued)
class _MessagesViewState extends State<MessagesView> {
  TextEditingController _controller;
  var _hears = ''; // TODO: everyone

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _hears = widget.whoInfos.first.user;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
            Row(
              children: [
                DropdownButton<String>(
                  value: _hears,
                  items: [
                    for (final item in ['everyone', 'players+watchers', 'watchers'])
                      DropdownMenuItem<String>(value: item, child: Text(item)),
                  ],
                  onChanged: (item) => setState(() => _source.filter = item),
                ),
                Expanded(child: TextField(controller: _controller, decoration: InputDecoration(labelText: 'message'))),
              ],
            ),
          ],
        ),
      );
}
*/

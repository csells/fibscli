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

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(App.title),
          actions: [OutlineButton(onPressed: () => App.fibs.logout(), child: Text('Logout'))],
        ),
        body: ChangeNotifierBuilder<NotifierList<WhoInfo>>(
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
                        style:
                            TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w500, fontSize: 36),
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
                  columns: <GridColumn>[
                    GridTextColumn(mappingName: 'user', headerText: 'user'),
                    GridNumericColumn(mappingName: 'experience', headerText: 'experiece'),
                    GridTextColumn(mappingName: 'opponent', headerText: 'opponent'),
                    GridNumericColumn(mappingName: 'rating', headerText: 'rating'),
                    GridTextColumn(mappingName: 'ready', headerText: 'ready'),
                    GridTextColumn(mappingName: 'watching', headerText: 'watching'),
                  ],
                ),
              ),
            ],
          ),
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
      case 'watching':
        return whoInfo.watching;
      default:
        throw 'unreachable: columnName= $columnName';
    }
  }
}

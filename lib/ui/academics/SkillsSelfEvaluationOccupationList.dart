import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:illinois/model/Occupation.dart';
import 'package:illinois/service/Occupations.dart';
import 'package:illinois/ui/academics/SkillsSelfEvaluationOccupationDetails.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:rokwire_plugin/service/connectivity.dart';
import 'package:rokwire_plugin/service/localization.dart';
import 'package:rokwire_plugin/service/styles.dart';
import 'package:rokwire_plugin/ui/widgets/section_header.dart';

class SkillSelfEvaluationOccupationListPanel extends StatefulWidget {
  final Map<String, num> percentages;

  SkillSelfEvaluationOccupationListPanel({Key? key, required this.percentages}) : super(key: key);

  @override
  _SkillSelfEvaluationOccupationListState createState() => _SkillSelfEvaluationOccupationListState();
}

class _SkillSelfEvaluationOccupationListState extends State<SkillSelfEvaluationOccupationListPanel> {

  final ScrollController _scrollController = ScrollController();
  Map<String, num> percentages = {};
  bool sortMatchAsc = false;

  @override
  void initState() {
    super.initState();
    percentages = widget.percentages;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HeaderBar(title: Localization().getStringEx('panel.skills_self_evaluation.occupation_list.header.title', 'Skills Self-Evaluation')),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: SectionSlantHeader(
          headerWidget: _buildHeader(),
          slantColor: Styles().colors?.gradientColorPrimary,
          slantPainterHeadingHeight: 0,
          backgroundColor: Styles().colors?.background,
          children: Connectivity().isOffline ? _buildOfflineMessage() : _buildOccupationListView(),
          childrenPadding: EdgeInsets.zero,
          allowOverlap: !Connectivity().isOffline,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(top: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            Localization().getStringEx('panel.skills_self_evaluation.occupation_list.section.title', 'Career Explorer'),
            style: Styles().textStyles?.getTextStyle('panel.skills_self_evaluation.get_started.header'),
            textAlign: TextAlign.center,
          ),
          _buildOccupationsHeader(),
        ],
      ),
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Styles().colors?.fillColorPrimaryVariant ?? Colors.transparent,
            Styles().colors?.gradientColorPrimary ?? Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildOccupationsHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, left: 28, right: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Divider(color: Styles().colors?.surface, thickness: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                    flex: 5,
                    fit: FlexFit.tight,
                    child: Text(
                      Localization().getStringEx('panel.skills_self_evaluation.occupation_list.occupation.title', 'OCCUPATION'),
                      style: Styles().textStyles?.getTextStyle('panel.skills_self_evaluation.results.table.header'),
                    )),
                Flexible(
                    flex: 5,
                    fit: FlexFit.tight,
                    child: InkWell(
                      onTap: _onTapToggleSortMatchPercentage,
                      child: Row(
                        children: [
                          Text(
                            Localization().getStringEx('panel.skills_self_evaluation.occupation_list.match.title', 'MATCH PERCENTAGE'),
                            style: Styles().textStyles?.getTextStyle('panel.skills_self_evaluation.results.table.header'),
                          ),
                          SizedBox(width: 8,),
                          (sortMatchAsc ? Styles().images?.getImage('chevron-down', excludeFromSemantics: true)
                              : Styles().images?.getImage('chevron-up', excludeFromSemantics: true)) ?? Container(),
                        ],
                      ),
                    ))
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOfflineMessage() {
    return [
      Padding(
        padding: EdgeInsets.all(28),
        child: Center(
            child: Text(
                Localization().getStringEx('panel.skills_self_evaluation.occupation_list.offline.error.msg', 'Career Explorer not available while offline.'),
                textAlign: TextAlign.center,
                style: Styles().textStyles?.getTextStyle('panel.skills_self_evaluation.content.title'))),
      ),
    ];
  }

  List<Widget> _buildOccupationListView() {
    return [
      FutureBuilder(
          future: Occupations().getAllOccupationMatches(),
          initialData: [],
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.data == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 100, left: 32.0, right: 32.0),
                  child: Text(
                    Localization().getStringEx('panel.skills_self_evaluation.occupation_list.unavailable.message',
                        'You do not have any matched occupations currently. Please take the survey first and wait for results to be processed.'),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            List<OccupationMatch> occupationMatches = (snapshot.data as List).cast<OccupationMatch>();
            if (sortMatchAsc) {// ascending
              occupationMatches.sort((a, b) => (b.matchPercent ?? 0).compareTo(a.matchPercent ?? 0));
            } else {// descending
              occupationMatches.sort((a, b) => (a.matchPercent ?? 0).compareTo(b.matchPercent ?? 0));
            }

            return ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                controller: _scrollController,
                shrinkWrap: true,
                itemCount: occupationMatches.length,
                itemBuilder: (BuildContext context, int index) {
                  return OccupationListTile(occupationMatch: occupationMatches[index], percentages: percentages,);
                }
            );
          }
      )
    ];
  }

  void _onTapToggleSortMatchPercentage() {
    setState(() {
      sortMatchAsc = !sortMatchAsc;
    });
  }
}

class OccupationListTile extends StatelessWidget {
  const OccupationListTile({Key? key, required this.occupationMatch, required this.percentages}) : super(key: key);

  final OccupationMatch occupationMatch;
  final Map<String, num> percentages;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Card(
        child: InkWell(
          onTap: () {
            Navigator.push(
                context, CupertinoPageRoute(builder: (context) => SkillsSelfEvaluationOccupationDetails(percentages: percentages, occupationMatch: occupationMatch)));
          },
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 12, left: 16),
            child: Row(
              children: [
                Flexible(
                  flex: 5,
                  fit: FlexFit.tight,
                  child: Text(
                    occupationMatch.occupation?.name.toString() ?? "",
                    style: Styles().textStyles?.getTextStyle('panel.skills_self_evaluation.content.title'),
                  ),
                ),
                Spacer(),
                Flexible(
                    flex: 2,
                    fit: FlexFit.tight,
                    child: Text(occupationMatch.matchPercent?.toInt().toString() ?? '--', style: Styles().textStyles?.getTextStyle('panel.skills_self_evaluation.results.score.current'), textAlign: TextAlign.center,)
                ),
                Flexible(
                    flex: 1,
                    fit: FlexFit.tight,
                    child: SizedBox(
                        height: 16.0,
                        child: Styles().images?.getImage('chevron-right-bold', excludeFromSemantics: true))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
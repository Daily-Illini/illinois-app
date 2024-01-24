/*
 * Copyright 2020 Board of Trustees of the University of Illinois.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'package:flutter/material.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Auth2.dart';
import 'package:illinois/ui/profile/ProfileDetailsPage.dart';
import 'package:illinois/ui/profile/ProfileLoginPage.dart';
import 'package:illinois/ui/profile/ProfileRolesPage.dart';
import 'package:illinois/ui/widgets/RibbonButton.dart';
import 'package:rokwire_plugin/service/localization.dart';
import 'package:rokwire_plugin/service/notification_service.dart';
import 'package:rokwire_plugin/service/styles.dart';

enum ProfileContent { profile, who_are_you, login }

class ProfileHomePanel extends StatefulWidget {
  static final String routeName = 'settings_profile_content_panel';

  final ProfileContent? content;

  ProfileHomePanel._({this.content});

  @override
  _ProfileHomePanelState createState() => _ProfileHomePanelState();

  static void present(BuildContext context, {ProfileContent? content}) {
    if (ModalRoute.of(context)?.settings.name != routeName) {
      MediaQueryData mediaQuery = MediaQueryData.fromView(View.of(context));
      double height = mediaQuery.size.height - mediaQuery.viewPadding.top - mediaQuery.viewInsets.top - 16;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        useRootNavigator: true,
        routeSettings: RouteSettings(name: routeName),
        clipBehavior: Clip.antiAlias,
        backgroundColor: Styles().colors.background,
        constraints: BoxConstraints(maxHeight: height, minHeight: height),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (context) {
          return ProfileHomePanel._(content: content);
        }
      );

      /*Navigator.push(context, PageRouteBuilder(
        settings: RouteSettings(name: routeName),
        pageBuilder: (context, animation1, animation2) => SettingsProfileContentPanel._(content: content),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero
      ));*/
    }
  }
}

class _ProfileHomePanelState extends State<ProfileHomePanel> implements NotificationsListener {
  static ProfileContent? _lastSelectedContent;
  late ProfileContent _selectedContent;
  bool _contentValuesVisible = false;
  final GlobalKey _pageKey = GlobalKey();
  final GlobalKey _pageHeadingKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    NotificationService().subscribe(this, [Auth2.notifyLoginChanged]);
    _initInitialContent();
  }

  @override
  void dispose() {
    NotificationService().unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //return _buildScaffold(context);
    return _buildSheet(context);
  }

  /*Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: RootHeaderBar(title: Localization().getStringEx('panel.settings.profile.header.profile.label', 'Profile')),
      body: _buildPage(context),
      backgroundColor: Styles().colors.background,
      bottomNavigationBar: uiuc.TabBar()
    );
  }*/

  Widget _buildSheet(BuildContext context) {
    // MediaQuery(data: MediaQueryData.fromWindow(WidgetsBinding.instance.window), child: SafeArea(bottom: false, child: ))
    return Column(children: [
      Container(color: Styles().colors.white, child:
        Row(children: [
          Expanded(child:
            Padding(padding: EdgeInsets.only(left: 16), child:
              Text(Localization().getStringEx('panel.settings.profile.header.profile.label', 'Profile'), style: Styles().textStyles.getTextStyle("widget.label.medium.fat"),)
            )
          ),
          Semantics( label: Localization().getStringEx('dialog.close.title', 'Close'), hint: Localization().getStringEx('dialog.close.hint', ''), inMutuallyExclusiveGroup: true, button: true, child:
            InkWell(onTap : _onTapClose, child:
              Container(padding: EdgeInsets.only(left: 8, right: 16, top: 16, bottom: 16), child:
                Styles().images.getImage('close', excludeFromSemantics: true),
              ),
            ),
          ),

        ],),
      ),
      Container(color: Styles().colors.surfaceAccent, height: 1,),
      Expanded(child:
        _buildPage(context),
      )
    ],);
  }

  Widget _buildPage(BuildContext context) {
    return Column(key: _pageKey, children: <Widget>[
      Expanded(child:
        SingleChildScrollView(physics: _contentValuesVisible ? NeverScrollableScrollPhysics() : null, child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(key: _pageHeadingKey, padding: EdgeInsets.only(left: 16, top: 16, right: 16), child:
              RibbonButton(
                textStyle: Styles().textStyles.getTextStyle("widget.button.title.medium.fat.secondary"),
                backgroundColor: Styles().colors.white,
                borderRadius: BorderRadius.all(Radius.circular(5)),
                border: Border.all(color: Styles().colors.surfaceAccent, width: 1),
                rightIconKey: (_contentValuesVisible ? 'chevron-up' : 'chevron-down'),
                label: _getContentLabel(_selectedContent),
                onTap: _changeSettingsContentValuesVisibility
              )
            ),
            _buildContent()
          ])
        )
      )
    ]);
  }


  Widget _buildContent() {
    return Stack(children: [
      Padding(padding: EdgeInsets.all(16), child: _contentWidget),
      Container(height: _contentHeight),
      _buildContentValuesContainer()
    ]);
  }

  Widget _buildContentValuesContainer() {
    return Visibility(visible: _contentValuesVisible, child:
      Positioned.fill(child:
        Stack(children: <Widget>[
          _buildContentDismissLayer(),
          _buildContentValuesWidget()
        ])
      )
    );
  }

  Widget _buildContentDismissLayer() {
    return Positioned.fill(child:
      BlockSemantics(child:
        GestureDetector(onTap: _onTapDismissLayer, child:
          Container(color: Styles().colors.blackTransparent06)
        )
      )
    );
  }

  Widget _buildContentValuesWidget() {
    List<Widget> contentList = <Widget>[];
    contentList.add(Container(color: Styles().colors.fillColorSecondary, height: 2));
    for (ProfileContent contentItem in ProfileContent.values) {
      if ((contentItem == ProfileContent.profile) && !Auth2().isLoggedIn) {
        continue;
      }
      if ((_selectedContent != contentItem)) {
        contentList.add(_buildContentItem(contentItem));
      }
    }
    return Padding(padding: EdgeInsets.symmetric(horizontal: 16), child:
      SingleChildScrollView(child:
        Column(children: contentList)
      )
    );
  }

  Widget _buildContentItem(ProfileContent contentItem) {
    return RibbonButton(
        backgroundColor: Styles().colors.white,
        border: Border.all(color: Styles().colors.surfaceAccent, width: 1),
        rightIconKey: null,
        label: _getContentLabel(contentItem),
        onTap: () => _onTapContentItem(contentItem));
  }

  void _initInitialContent() {
    // Do not allow not logged in users to view "Profile" content
    if (!Auth2().isLoggedIn && (_lastSelectedContent == ProfileContent.profile)) {
      _lastSelectedContent = null;
    }
    _selectedContent =
        widget.content ?? (_lastSelectedContent ?? (Auth2().isLoggedIn ? ProfileContent.profile : ProfileContent.login));
  }

  void _onTapContentItem(ProfileContent contentItem) {
    Analytics().logSelect(target: contentItem.toString(), source: widget.runtimeType.toString());
    _selectedContent = _lastSelectedContent = contentItem;
    _changeSettingsContentValuesVisibility();
  }

  void _changeSettingsContentValuesVisibility() {
    _contentValuesVisible = !_contentValuesVisible;
    if (mounted) {
      setState(() {});
    }
  }

  Widget get _contentWidget {
    switch (_selectedContent) {
      case ProfileContent.profile:
        return ProfileDetailsPage(parentRouteName: ProfileHomePanel.routeName,);
      case ProfileContent.who_are_you:
        return ProfileRolesPage();
      case ProfileContent.login:
        return ProfileLoginPage();
      default:
        return Container();
    }
  }

  void _onTapClose() {
    Analytics().logSelect(target: 'Close', source: widget.runtimeType.toString());
    Navigator.of(context).pop();
  }

  void _onTapDismissLayer() {
    setState(() {
      _contentValuesVisible = false;
    });
  }

  // Utilities

  double? get _contentHeight  {
    RenderObject? pageRenderBox = _pageKey.currentContext?.findRenderObject();
    double? pageHeight = (pageRenderBox is RenderBox) ? pageRenderBox.size.height : null;

    RenderObject? pageHeaderRenderBox = _pageHeadingKey.currentContext?.findRenderObject();
    double? pageHeaderHeight = (pageHeaderRenderBox is RenderBox) ? pageHeaderRenderBox.size.height : null;

    return ((pageHeight != null) && (pageHeaderHeight != null)) ? (pageHeight - pageHeaderHeight) : null;
  }

  String _getContentLabel(ProfileContent content) {
    switch (content) {
      case ProfileContent.profile:
        return Localization().getStringEx('panel.settings.profile.content.profile.label', 'My Profile');
      case ProfileContent.who_are_you:
        return Localization().getStringEx('panel.settings.profile.content.who_are_you.label', 'Who Are You');
      case ProfileContent.login:
        return Localization().getStringEx('panel.settings.profile.content.login.label', 'Sign In/Sign Out');
    }
  }

  // NotificationsListener

  @override
  void onNotification(String name, param) {
    if (name == Auth2.notifyLoginChanged) {
      if ((_selectedContent == ProfileContent.profile) && !Auth2().isLoggedIn) {
        // Do not allow not logged in users to view "Profile" content
        _selectedContent = _lastSelectedContent = ProfileContent.login;
      }
      if (mounted) {
        setState(() {});
      }
    }
  }
  
}

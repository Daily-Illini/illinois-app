import 'dart:async';
import 'dart:math';

import 'package:expandable_page_view/expandable_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:illinois/model/Twitter.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/ui/home/HomePanel.dart';
import 'package:illinois/ui/home/HomeWidgets.dart';
import 'package:illinois/ui/widgets/FavoriteButton.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:rokwire_plugin/service/app_livecycle.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/FlexUI.dart';
//import 'package:rokwire_plugin/service/config.dart' as rokwire;
import 'package:rokwire_plugin/service/notification_service.dart';
import 'package:rokwire_plugin/service/styles.dart';
import 'package:illinois/service/Twitter.dart';
import 'package:rokwire_plugin/ui/widgets/triangle_painter.dart';
import 'package:rokwire_plugin/utils/utils.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeTwitterWidget extends StatefulWidget {

  final String? favoriteId;
  final StreamController<String>? updateController;

  HomeTwitterWidget({Key? key, this.favoriteId, this.updateController}) : super(key: key);

  static Widget handle({String? favoriteId, HomeDragAndDropHost? dragAndDropHost, int? position}) =>
    HomeHandleWidget(favoriteId: favoriteId, dragAndDropHost: dragAndDropHost, position: position,
      title: title,
    );

  static String get title => 'Twitter' /* TBD: Localization */;
  
  @override
  _HomeTwitterWidgetState createState() => _HomeTwitterWidgetState();
}

class _HomeTwitterWidgetState extends State<HomeTwitterWidget> implements NotificationsListener {

  List<TweetsPage> _tweetsPages = <TweetsPage>[];
  String? _tweetsAccountKey;
  String? _selectedAccountKey;
  bool _loadingPage = false;
  DateTime? _pausedDateTime;
  PageController? _pageController;
  GlobalKey _viewPagerKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    NotificationService().subscribe(this, [
      AppLivecycle.notifyStateChanged,
      FlexUI.notifyChanged,
    ]);

    if (widget.updateController != null) {
      widget.updateController!.stream.listen((String command) {
        if (command == HomePanel.notifyRefresh) {
          _refresh(noCache: true);
        }
      });
    }

    _selectedAccountKey = Storage().selectedTwitterAccount;
    _loadingPage = true;
    String? accountKey = _currentAccountKey;
    Twitter().loadTweetsPage(count: Config().twitterTweetsCount, accountKey: accountKey).then((TweetsPage? tweetsPage) {
      _setState(() {
        _loadingPage = false;
        if (tweetsPage != null) {
          _tweetsPages.add(tweetsPage);
          _tweetsAccountKey = accountKey;
        }
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _pageController?.dispose();
    NotificationService().unsubscribe(this);
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == AppLivecycle.notifyStateChanged) {
      _onAppLivecycleStateChanged(param);
    }
    else if (name == FlexUI.notifyChanged) {
      _onTwitterAccountChanged();
    }
  }

  void _onAppLivecycleStateChanged(AppLifecycleState? state) {
    if (state == AppLifecycleState.paused) {
      _pausedDateTime = DateTime.now();
    }
    else if (state == AppLifecycleState.resumed) {
      if (_pausedDateTime != null) {
        Duration pausedDuration = DateTime.now().difference(_pausedDateTime!);
        if (Config().refreshTimeout < pausedDuration.inSeconds) {
          _refresh(/*count: Config().twitterTweetsCount*/);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int displayPagesCount = _tweetsCount + ((_loadingPage == true) ? 1 : 0);
    return Visibility(visible: (0 < displayPagesCount), child:
        Semantics(container: true, child:
          Column(children: <Widget>[
            _buildHeader(),
            Stack(children:<Widget>[
              _buildSlant(),
              _buildContent(),
            ]),
          ]),
        ),
    );
  }

  Widget _buildHeader() {
    return Semantics(child:
      Padding(padding: EdgeInsets.zero, child: 
        Container(color: Styles().colors!.fillColorPrimary, child:
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

            HomeTitleIcon(image: Image.asset('images/campus-tools.png')),

            Expanded(child:
              Padding(padding: EdgeInsets.only(top: 14), child:
                Semantics(label: 'Twitter' /* TBD: Localization */, header: true, excludeSemantics: true, child:
                  Text('Twitter' /* TBD: Localization */, style: TextStyle(color: Styles().colors?.textColorPrimary, fontFamily: Styles().fontFamilies?.extraBold, fontSize: 20),)
                )
              )
            ),

            (1 < _accountKeys.length) ?
              Semantics(container: true,  button: true, child: _buildAccountDropDown(), ) :
              Container(),

            HomeFavoriteButton(favorite: HomeFavorite(widget.favoriteId), style: FavoriteIconStyle.SlantHeader, prompt: true),
            
        ],),),),);
  }

  Widget _buildAccountDropDown() {
    String? currentAccountName = twitterAccountName(_currentAccountKey);

    return Semantics(label: currentAccountName, hint: "Double tap to select account", button: true, container: true, child:
      DropdownButtonHideUnderline(child:
        DropdownButton<String>(
          icon: Padding(padding: EdgeInsets.only(left: 4), child: Image.asset('images/icon-down-white.png')),
          isExpanded: false,
          style: TextStyle(color: Styles().colors?.white, fontFamily: Styles().fontFamilies?.medium, fontSize: 16, ),
          hint: (currentAccountName != null) ? Text(currentAccountName, style: TextStyle(color: Styles().colors?.white, fontFamily: Styles().fontFamilies?.medium, fontSize: 16)) : null,
          items: _buildDropDownItems(),
          onChanged: _onDropDownValueChanged
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>>? _buildDropDownItems() {
    List<DropdownMenuItem<String>> dropDownItems = [];
    for (String accountKey in _accountKeys) {
      String? accountName = twitterAccountName(accountKey);
      dropDownItems.add(DropdownMenuItem<String>(value: accountKey, child:
        // BlockSemantics(blocking: true, child:
          Semantics(label: accountName, hint: "Double tap to select account", button:false, excludeSemantics: true,child:
            Text(accountName ?? '', style: TextStyle(color: Styles().colors?.fillColorPrimary, fontFamily: Styles().fontFamilies?.medium, fontSize: 16)),
          )
        // )
      ));
    }
    return dropDownItems;
  }

  Widget _buildSlant() {
    return Column(children: <Widget>[
      Container(color:  Styles().colors!.fillColorPrimary, height: 45,),
      Container(color: Styles().colors!.fillColorPrimary, child:
        CustomPaint(painter: TrianglePainter(painterColor: Styles().colors!.background, horzDir: TriangleHorzDirection.rightToLeft), child:
          Container(height: 65,),
        )),
    ],);
  }

  Widget _buildContent() {
    List<Widget> pages = <Widget>[];
    for (TweetsPage tweetsPage in _tweetsPages) {
      if (tweetsPage.tweets != null) {
        for (Tweet? tweet in tweetsPage.tweets!) {
          bool isFirst = pages.isEmpty;
          pages.add(_TweetWidget(
            tweet: tweet,
            margin: EdgeInsets.only(bottom: 5, right: 20),
            onTapPrevious: isFirst? null : _onTapPrevious,
            onTapNext: _onTapNext,
          ));
        }
      }
    }

    if (_loadingPage == true) {
      pages.add(_TweetLoadingWidget(
        progressColor: Styles().colors!.white!,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24)
      ));
    }

    double screenWidth = MediaQuery.of(context).size.width;
    double pageHeight = screenWidth - 20 * 2 + 5;
    double pageViewport = (screenWidth - 40) / screenWidth;
    
    if (_pageController == null) {
      _pageController = PageController(viewportFraction: pageViewport, keepPage: true, initialPage: 0);
    }

    return
      Padding(padding: EdgeInsets.only(top: 10, bottom: 50), child:
        Container(
          constraints: BoxConstraints(minHeight: 20),
          child: ExpandablePageView(key: _viewPagerKey, controller: _pageController, onPageChanged: _onPageChanged, children: pages, estimatedPageSize: pageHeight,)
        )
      );
  }

  int get _tweetsCount {
    int tweetsCount = 0;
    for (TweetsPage tweetsPage in _tweetsPages) {
      tweetsCount += (tweetsPage.tweets?.length ?? 0);
    }
    return tweetsCount;
  }

  void _onPageChanged(int index) {
    if ((_tweetsCount <= (index + 1)) && (_loadingPage != true)) {
      _setStateDelayed(() {
        _loadingPage = true;
      });
      TweetsPage? lastTweetsPage = (0 < _tweetsPages.length) ? _tweetsPages.last : null;
      Tweet? lastTweet = ((lastTweetsPage?.tweets != null) && (0 < lastTweetsPage!.tweets!.length)) ? lastTweetsPage.tweets!.last : null;
      String? accountKey = _currentAccountKey;
      Twitter().loadTweetsPage(count: Config().twitterTweetsCount, endTimeUtc: lastTweet?.createdAtUtc, accountKey: accountKey).then((TweetsPage? tweetsPage) {
        _setState(() {
          _loadingPage = false;
          if (tweetsPage != null) {
            _tweetsPages.add(tweetsPage);
            _tweetsAccountKey = accountKey;
          }
        });
      });
    }
  }

  void _refresh({int? count, bool? noCache}) {
    _setState(() {
      _loadingPage = true;
    });
    String? accountKey = _currentAccountKey;
    Twitter().loadTweetsPage(
        count: count ?? max(_tweetsCount, Config().twitterTweetsCount!),
        noCache: noCache,
        accountKey: accountKey).then((TweetsPage? tweetsPage) {
          _setState(() {
            _loadingPage = false;
            if (tweetsPage != null) {
              _tweetsPages = [tweetsPage];
              _tweetsAccountKey = accountKey;
            }
          });
        // Future.delayed((Duration.zero),(){
        if (mounted && (tweetsPage != null)) {
          _pageController!.animateToPage(
              0, duration: Duration(milliseconds: 500), curve: Curves.easeIn);
        }
        // });
      });
  }

  void _onTapPrevious(){
   _pageController?.previousPage(duration:  Duration(milliseconds: 500), curve: Curves.easeIn);
  }

  void _onTapNext(){
    _pageController?.nextPage(duration:  Duration(milliseconds: 500), curve: Curves.easeIn);
  }

  String get _currentAccountKey => _selectedAccountKey ?? _defaultAccountKey;

  static String get _defaultAccountKey => _accountKeys.first;

  static List<String> get _accountKeys => JsonUtils.listStringsValue(FlexUI()['home.twitter.account']) ?? [ Config.twitterDefaultAccountKey ];

  static String? twitterAccountName(String accountKey) {
    String? accountName = Config().twitterAccountName(accountKey);
    return (accountName != null) ? "@$accountName" : null;
  }

  void _onDropDownValueChanged(String? value) {
    Analytics().logSelect(target: "Twitter account selected: $value");
    Storage().selectedTwitterAccount = _selectedAccountKey = (value != _defaultAccountKey) ? value : null;
    _refresh(count: Config().twitterTweetsCount);
  }

  void _onTwitterAccountChanged() {
    if ((_selectedAccountKey != null) && (!_accountKeys.contains(_selectedAccountKey) || (_selectedAccountKey == _defaultAccountKey))) {
      Storage().selectedTwitterAccount = _selectedAccountKey = null;
    }
    if ((_tweetsAccountKey != _currentAccountKey)) {
      _refresh(count: Config().twitterTweetsCount);
    }
    else if (mounted) {
      setState(() {});
    }
  }

  void _setState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void _setStateDelayed(VoidCallback fn, { Duration duration = Duration.zero }) {
    Future.delayed(duration, () {
      if (mounted) {
        setState(fn);
      }
    });
  }
}

class TwitterPanel extends StatefulWidget {
  TwitterPanel({Key? key}) : super(key: key);

  @override
  _TwitterPanelState createState() => _TwitterPanelState();
}

class _TwitterPanelState extends State<TwitterPanel> implements NotificationsListener  {

  List<TweetsPage> _tweetsPages = <TweetsPage>[];
  String? _tweetsAccountKey;
  String? _selectedAccountKey;
  bool _loadingPage = false;
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {

    NotificationService().subscribe(this, [
      FlexUI.notifyChanged,
    ]);

    _selectedAccountKey = Storage().selectedTwitterAccount;
    _loadingPage = true;
    String? accountKey = _currentAccountKey;

    Twitter().loadTweetsPage(count: Config().twitterTweetsCount, accountKey: accountKey).then((TweetsPage? tweetsPage) {
      if (mounted) {
        setState(() {
          _loadingPage = false;
          if (tweetsPage != null) {
            _tweetsPages.add(tweetsPage);
            _tweetsAccountKey = accountKey;
          }
        });
      }
    });

    _scrollController.addListener(_scrollListener);

    super.initState();
  }

  @override
  void dispose() {
    NotificationService().unsubscribe(this);
    super.dispose();
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == FlexUI.notifyChanged) {
      _onTwitterAccountChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HeaderBar(
        title: 'Twitter' /* TBD: Localization */,
        actions: _buildActions(),
      ),
      body: RefreshIndicator(onRefresh: _onPullToRefresh, child:
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Expanded(child:
            _buildContent(),
          ),
        ],)),
      backgroundColor: Styles().colors!.background,
    );
  }

  List<Widget>? _buildActions() {
    String? currentAccountName = twitterAccountName(_currentAccountKey);
    return (1 < _accountKeys.length) ? <Widget>[
      Semantics(label: currentAccountName, hint: "Double tap to select account", button: true, container: true, child:
        DropdownButtonHideUnderline(child:
          DropdownButton<String>(
            icon: Padding(padding: EdgeInsets.only(left: 4, right: 16), child: Image.asset('images/icon-down-white.png')),
            isExpanded: false,
            style: TextStyle(color: Styles().colors?.white, fontFamily: Styles().fontFamilies?.medium, fontSize: 16, ),
            hint: (currentAccountName != null) ? Text(currentAccountName, style: TextStyle(color: Styles().colors?.white, fontFamily: Styles().fontFamilies?.medium, fontSize: 16)) : null,
            items: _buildDropDownItems(),
            onChanged: _onDropDownValueChanged
          ),
        ),
      ),
    ] : null;
  }


  List<DropdownMenuItem<String>>? _buildDropDownItems() {
    List<DropdownMenuItem<String>> dropDownItems = [];
    for (String accountKey in _accountKeys) {
      String? accountName = twitterAccountName(accountKey);
      dropDownItems.add(DropdownMenuItem<String>(value: accountKey, child:
        // BlockSemantics(blocking: true, child:
          Semantics(label: accountName, hint: "Double tap to select account", button:false, excludeSemantics: true,child:
            Text(accountName ?? '', style: TextStyle(color: Styles().colors?.fillColorPrimary, fontFamily: Styles().fontFamilies?.medium, fontSize: 16)),
          )
        // )
      ));
    }
    return dropDownItems;
  }

  Widget _buildContent() {
    if (_tweetsPages.isEmpty && _loadingPage == true) {
      return Center(child: 
        SizedBox(height: 32, width: 32, child:
          CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color?>(Styles().colors!.fillColorPrimary!), )
        ),
      );
    }
    else {
      int displayPagesCount = _tweetsCount + ((_loadingPage == true) ? 1 : 0);
      if (0 < displayPagesCount) {
        return ListView.separated(
            separatorBuilder: (context, index) => Container(height: 24),
            itemCount: displayPagesCount,
            itemBuilder: _buildListEntry,
            controller: _scrollController);
      }
      else {
        return Column(children: <Widget>[
          Expanded(child: Container(), flex: 1),
          Text('No tweets' /* TBD: Localization */, textAlign: TextAlign.center,),
          Expanded(child: Container(), flex: 3),
        ]);
      }
    }
  }

  Widget _buildListEntry(BuildContext context, int index) {
    Tweet? tweet = _tweet(index);
    return (tweet != null) ? 
      _TweetWidget(
        tweet: tweet,
        margin: (0 < index) ? EdgeInsets.symmetric(horizontal: 16) : EdgeInsets.only(left: 16, right: 16, top: 16)
      ) :
      _TweetLoadingWidget(
        progressColor: Styles().colors!.fillColorPrimary!,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: _tweetsPages.isNotEmpty ? 48 : 192)
      );
  }

  void _refresh({int? count, bool? noCache}) {
    if (mounted) {
      setState(() {
        _loadingPage = true;
      });
    }
    String? accountKey = _currentAccountKey;
    Twitter().loadTweetsPage(
        count: count ?? max(_tweetsCount, Config().twitterTweetsCount!),
        noCache: noCache,
        accountKey: accountKey).then((TweetsPage? tweetsPage) {
          if (mounted) {
            setState(() {
              _loadingPage = false;
              if (tweetsPage != null) {
                _tweetsPages = [tweetsPage];
                _tweetsAccountKey = accountKey;
              }
            });
          }
      });
  }

  void _loadMore() {
    if (mounted) {
      setState(() {
        _loadingPage = true;
      });
    }
    TweetsPage? lastTweetsPage = (0 < _tweetsPages.length) ? _tweetsPages.last : null;
    Tweet? lastTweet = ((lastTweetsPage?.tweets != null) && (0 < lastTweetsPage!.tweets!.length)) ? lastTweetsPage.tweets!.last : null;
    String? accountKey = _currentAccountKey;
    Twitter().loadTweetsPage(count: Config().twitterTweetsCount, endTimeUtc: lastTweet?.createdAtUtc, accountKey: accountKey).then((TweetsPage? tweetsPage) {
      if (mounted) {
        setState(() {
          _loadingPage = false;
          if (tweetsPage != null) {
            _tweetsPages.add(tweetsPage);
            _tweetsAccountKey = accountKey;
          }
        });
      }
    });
  }

  Future<void> _onPullToRefresh() async {
    String? accountKey = _currentAccountKey;
    TweetsPage? tweetsPage = await Twitter().loadTweetsPage(
      count: max(_tweetsCount, Config().twitterTweetsCount!),
      noCache: true,
      accountKey: accountKey);
    if ((tweetsPage != null) && mounted) {
      _tweetsPages = [tweetsPage];
      _tweetsAccountKey = accountKey;
    }
  }

  int get _tweetsCount {
    int tweetsCount = 0;
    for (TweetsPage tweetsPage in _tweetsPages) {
      tweetsCount += (tweetsPage.tweets?.length ?? 0);
    }
    return tweetsCount;
  }

  Tweet? _tweet(int tweetIndex) {
    for (TweetsPage tweetsPage in _tweetsPages) {
      if ((0 <= tweetIndex) && (tweetIndex < (tweetsPage.tweets?.length ?? 0))) {
        return tweetsPage.tweets![tweetIndex];
      }
      else {
        tweetIndex -= (tweetsPage.tweets?.length ?? 0);
      }
    }
    return null;
  }

  String get _currentAccountKey => _selectedAccountKey ?? _defaultAccountKey;

  static String get _defaultAccountKey => _accountKeys.first;

  static List<String> get _accountKeys => JsonUtils.listStringsValue(FlexUI()['home.twitter.account']) ?? [ Config.twitterDefaultAccountKey ];

  static String? twitterAccountName(String accountKey) {
    String? accountName = Config().twitterAccountName(accountKey);
    return (accountName != null) ? "@$accountName" : null;
  }

  void _onDropDownValueChanged(String? value) {
    Analytics().logSelect(target: "Twitter account selected: $value");
    Storage().selectedTwitterAccount = _selectedAccountKey = (value != _defaultAccountKey) ? value : null;
    _refresh(count: Config().twitterTweetsCount);
  }

  void _onTwitterAccountChanged() {
    if ((_selectedAccountKey != null) && (!_accountKeys.contains(_selectedAccountKey) || (_selectedAccountKey == _defaultAccountKey))) {
      Storage().selectedTwitterAccount = _selectedAccountKey = null;
    }
    if ((_tweetsAccountKey != _currentAccountKey)) {
      _refresh(count: Config().twitterTweetsCount);
    }
    else if (mounted) {
      setState(() {});
    }
  }

  void _scrollListener() {
    if ((_scrollController.offset >= _scrollController.position.maxScrollExtent) && (_loadingPage != true)) {
      _loadMore();
    }
  }
}

class _TweetWidget extends StatelessWidget {

  final Tweet? tweet;
  final EdgeInsetsGeometry? margin;
  final void Function()? onTapNext;
  final void Function()? onTapPrevious;

  _TweetWidget({this.tweet, this.margin, this.onTapNext, this.onTapPrevious});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: margin ?? EdgeInsets.zero, child:
      Container(
        decoration: BoxDecoration(
            color: Styles().colors!.white,
            boxShadow: [BoxShadow(color: Styles().colors!.blackTransparent018!, spreadRadius: 1.0, blurRadius: 3.0, offset: Offset(1, 1))],
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(4)) // BorderRadius.all(Radius.circular(4))
        ),
        clipBehavior: Clip.none,
        child:
          Column(children: <Widget>[
                Column(children: [
                  StringUtils.isNotEmpty(tweet?.media?.imageUrl) ?
                    InkWell(onTap: () => _onTap(context), child:
                      Image.network(tweet!.media!.imageUrl!, excludeFromSemantics: true)) :
                  Container(),
                  Padding(padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20), child:
                    //Text(tweet.text, style: TextStyle(color: Styles().colors.fillColorPrimary, fontFamily: Styles().fontFamilies.medium, fontSize: 16, ),),
                    Html(data: tweet!.html,
                      onLinkTap: (url, renderContext, attributes, element) => _launchUrl(url, context: context),
                      style: { "body": Style(color: Styles().colors!.fillColorPrimary, fontFamily: Styles().fontFamilies!.medium, fontSize: FontSize(16), padding: EdgeInsets.zero, margin: EdgeInsets.zero), },),
                  ),
                ],),
            Padding(padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20), child:
              Row(children: [
                Expanded(child: StringUtils.isNotEmpty(tweet?.author?.userName) ?
                  //Text("@${tweet?.author?.userName}", style: TextStyle(color: Styles().colors.textSurface, fontFamily: Styles().fontFamilies.medium, fontSize: 14, ),) :
                  Html(data: tweet?.author?.html,
                    onLinkTap: (url, renderContext, attributes, element) => _launchUrl(url, context: context),
                    style: { "body": Style(color: Styles().colors!.textSurface, fontFamily: Styles().fontFamilies!.medium, fontSize: FontSize(14), padding: EdgeInsets.zero, margin: EdgeInsets.zero), },) :
                  Container(),
                ),
                Text(tweet?.displayTime ?? '', style: TextStyle(color: Styles().colors!.textSurface, fontFamily: Styles().fontFamilies!.medium, fontSize: 14, ),),
              ],)
            ),

            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Visibility(
                  visible: onTapPrevious!=null,
                  child: Semantics(
                    label: "Previous Page",
                    button: true,
                    child: GestureDetector(
                      onTap: onTapPrevious?? (){},
                      child: Container(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          "<",
                          semanticsLabel: "",
                          style: TextStyle(
                            color : Styles().colors!.fillColorPrimary,
                            fontFamily: Styles().fontFamilies!.bold,
                            fontSize: 26,
                          ),),)
                    )
                  )
                ),
                Visibility(
                  visible: onTapNext!=null,
                  child: Semantics(
                    label: "Next Page",
                    button: true,
                    child: GestureDetector(
                      onTap: onTapNext?? (){},
                      child: Container(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          ">",
                          semanticsLabel: "",
                          style: TextStyle(
                            color : Styles().colors!.fillColorPrimary,
                            fontFamily: Styles().fontFamilies!.bold,
                            fontSize: 26,
                          ),),)
                    )
                  )
                )
              ],
            )
          ])
      )
    );
  }

  void _onTap(BuildContext context) {
    _launchUrl(tweet!.detailUrl, context: context);
  }

  void _launchUrl(String? url, {BuildContext? context}) {
    if (StringUtils.isNotEmpty(url)) {
      launch(url!);
    }
  }
}

class _TweetLoadingWidget extends StatelessWidget {

  final Color progressColor;
  final EdgeInsetsGeometry padding;
  _TweetLoadingWidget({required this.progressColor, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: padding, child:
      Container(
        color: Colors.transparent,
        clipBehavior: Clip.none,
        child:
          Center(child: 
            SizedBox(height: 24, width: 24, child:
              CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color?>(progressColor), )
            ),
          ),
      )
    );
  }
}
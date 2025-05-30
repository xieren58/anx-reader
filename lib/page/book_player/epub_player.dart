import 'dart:async';
import 'dart:convert';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/dao/book.dart';
import 'package:anx_reader/dao/book_note.dart';
import 'package:anx_reader/dao/theme.dart';
import 'package:anx_reader/main.dart';
import 'package:anx_reader/models/book.dart';
import 'package:anx_reader/models/book_style.dart';
import 'package:anx_reader/models/font_model.dart';
import 'package:anx_reader/models/read_theme.dart';
import 'package:anx_reader/models/reading_rules.dart';
import 'package:anx_reader/models/search_result_model.dart';
import 'package:anx_reader/models/toc_item.dart';
import 'package:anx_reader/page/book_player/image_viewer.dart';
import 'package:anx_reader/page/home_page.dart';
import 'package:anx_reader/page/reading_page.dart';
import 'package:anx_reader/providers/book_list.dart';
import 'package:anx_reader/service/book_player/book_player_server.dart';
import 'package:anx_reader/utils/coordinates_to_part.dart';
import 'package:anx_reader/utils/js/convert_dart_color_to_js.dart';
import 'package:anx_reader/models/book_note.dart';
import 'package:anx_reader/utils/webView/webview_console_message.dart';
import 'package:anx_reader/utils/webView/webview_initial_variable.dart';
import 'package:anx_reader/widgets/bookshelf/book_cover.dart';
import 'package:anx_reader/widgets/context_menu/context_menu.dart';
import 'package:anx_reader/widgets/reading_page/more_settings/page_turning/diagram.dart';
import 'package:anx_reader/widgets/reading_page/more_settings/page_turning/types_and_icons.dart';
import 'package:anx_reader/widgets/reading_page/style_widget.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:intl/intl.dart';

class EpubPlayer extends ConsumerStatefulWidget {
  final Book book;
  final String? cfi;
  final Function showOrHideAppBarAndBottomBar;
  final Function onLoadEnd;

  const EpubPlayer(
      {super.key,
      required this.showOrHideAppBarAndBottomBar,
      required this.book,
      this.cfi,
      required this.onLoadEnd});

  @override
  ConsumerState<EpubPlayer> createState() => EpubPlayerState();
}

class EpubPlayerState extends ConsumerState<EpubPlayer>
    with TickerProviderStateMixin {
  late InAppWebViewController webViewController;
  late ContextMenu contextMenu;
  String cfi = '';
  double percentage = 0.0;
  String chapterTitle = '';
  String chapterHref = '';
  int chapterCurrentPage = 0;
  int chapterTotalPages = 0;
  List<TocItem> toc = [];
  OverlayEntry? contextMenuEntry;
  AnimationController? _animationController;
  Animation<double>? _animation;
  double searchProcess = 0.0;
  List<SearchResultModel> searchResult = [];
  bool showHistory = false;
  bool canGoBack = false;
  bool canGoForward = false;
  late Book book;
  String? backgroundColor;
  String? textColor;
  Timer? styleTimer;

  final StreamController<double> _searchProgressController =
      StreamController<double>.broadcast();

  Stream<double> get searchProgressStream => _searchProgressController.stream;

  final StreamController<List<SearchResultModel>> _searchResultController =
      StreamController<List<SearchResultModel>>.broadcast();

  Stream<List<SearchResultModel>> get searchResultStream =>
      _searchResultController.stream;

  FocusNode focusNode = FocusNode();

  void prevPage() {
    webViewController.evaluateJavascript(source: 'prevPage()');
  }

  void nextPage() {
    webViewController.evaluateJavascript(source: 'nextPage()');
  }

  void prevChapter() {
    webViewController.evaluateJavascript(source: '''
      prevSection()
      ''');
  }

  void nextChapter() {
    webViewController.evaluateJavascript(source: '''
      nextSection()
      ''');
  }

  Future<void> goToPercentage(double value) async {
    await webViewController.evaluateJavascript(source: '''
      goToPercent($value); 
      ''');
  }

  void changeTheme(ReadTheme readTheme) {
    String backgroundColor = convertDartColorToJs(readTheme.backgroundColor);
    String textColor = convertDartColorToJs(readTheme.textColor);

    webViewController.evaluateJavascript(source: '''
      changeStyle({
        backgroundColor: '#$backgroundColor',
        fontColor: '#$textColor',
      })
      ''');
  }

  void changeStyle(BookStyle bookStyle) {
    styleTimer?.cancel();
    styleTimer = Timer(const Duration(milliseconds: 300), () {
      webViewController.evaluateJavascript(source: '''
      changeStyle({
        fontSize: ${bookStyle.fontSize},
        spacing: ${bookStyle.lineHeight},
        fontWeight: ${bookStyle.fontWeight},
        paragraphSpacing: ${bookStyle.paragraphSpacing},
        topMargin: ${bookStyle.topMargin},
        bottomMargin: ${bookStyle.bottomMargin},
        sideMargin: ${bookStyle.sideMargin},
        letterSpacing: ${bookStyle.letterSpacing},
        textIndent: ${bookStyle.indent},
        maxColumnCount: ${bookStyle.maxColumnCount},
      })
      ''');
    });
  }

  void changeReadingRules(ReadingRules readingRules) {
    webViewController.evaluateJavascript(source: '''
      readingFeatures({
        convertChineseMode: '${readingRules.convertChineseMode.name}',
        bionicReadingMode: ${readingRules.bionicReading},
      })
    ''');
  }

  void changeFont(FontModel font) {
    webViewController.evaluateJavascript(source: '''
      changeStyle({
        fontName: '${font.name}',
        fontPath: '${font.path}',
      })
    ''');
  }

  void changePageTurnStyle(PageTurn pageTurnStyle) {
    webViewController.evaluateJavascript(source: '''
      changeStyle({
        pageTurnStyle: '${pageTurnStyle.name}',
      })
    ''');
  }

  void goToHref(String href) =>
      webViewController.evaluateJavascript(source: "goToHref('$href')");

  void goToCfi(String cfi) =>
      webViewController.evaluateJavascript(source: "goToCfi('$cfi')");

  void addAnnotation(BookNote bookNote) {
    webViewController.evaluateJavascript(source: '''
      addAnnotation({
        id: ${bookNote.id},
        type: '${bookNote.type}',
        value: '${bookNote.cfi}',
        color: '#${bookNote.color}',
        note: '${bookNote.content}',
      })
      ''');
  }

  void removeAnnotation(String cfi) =>
      webViewController.evaluateJavascript(source: "removeAnnotation('$cfi')");

  void clearSearch() {
    webViewController.evaluateJavascript(source: "clearSearch()");
    searchResult.clear();
    _searchResultController.add(searchResult);
  }

  void search(String text) {
    clearSearch();
    webViewController.evaluateJavascript(source: '''
      search('$text', {
        'scope': 'book',
        'matchCase': false,
        'matchDiacritics': false,
        'matchWholeWords': false,
      })
    ''');
  }

  Future<void> initTts() async =>
      await webViewController.evaluateJavascript(source: "ttsHere()");

  void ttsStop() => webViewController.evaluateJavascript(source: "ttsStop()");

  Future<String> ttsNext() async => (await webViewController
          .callAsyncJavaScript(functionBody: "return await ttsNext()"))
      ?.value;

  Future<String> ttsPrev() async => (await webViewController
          .callAsyncJavaScript(functionBody: "return await ttsPrev()"))
      ?.value;

  Future<String> ttsPrevSection() async => (await webViewController
          .callAsyncJavaScript(functionBody: "return await ttsPrevSection()"))
      ?.value;

  Future<String> ttsNextSection() async => (await webViewController
          .callAsyncJavaScript(functionBody: "return await ttsNextSection()"))
      ?.value;

  Future<String> ttsPrepare() async =>
      (await webViewController.evaluateJavascript(source: "ttsPrepare()"));

  void backHistory() {
    webViewController.evaluateJavascript(source: "back()");
  }

  void forwardHistory() {
    webViewController.evaluateJavascript(source: "forward()");
  }

  Future<String> theChapterContent() async =>
      await webViewController.evaluateJavascript(
        source: "theChapterContent()",
      );

  Future<String> previousContent(int count) async =>
      await webViewController.evaluateJavascript(
        source: "previousContent($count)",
      );

  void onClick(Map<String, dynamic> location) {
    readingPageKey.currentState?.resetAwakeTimer();
    if (contextMenuEntry != null) {
      removeOverlay();
      return;
    }
    final x = location['x'];
    final y = location['y'];
    final part = coordinatesToPart(x, y);
    final currentPageTurningType = Prefs().pageTurningType;
    final pageTurningType = pageTurningTypes[currentPageTurningType];
    switch (pageTurningType[part]) {
      case PageTurningType.prev:
        prevPage();
        break;
      case PageTurningType.next:
        nextPage();
        break;
      case PageTurningType.menu:
        widget.showOrHideAppBarAndBottomBar(true);
        break;
    }
  }

  Future<void> renderAnnotations(InAppWebViewController controller) async {
    List<BookNote> annotationList =
        await selectBookNotesByBookId(widget.book.id);
    String allAnnotations =
        jsonEncode(annotationList.map((e) => e.toJson()).toList())
            .replaceAll('\'', '\\\'');
    controller.evaluateJavascript(source: '''
     const allAnnotations = $allAnnotations
     renderAnnotations()
    ''');
  }

  Future<void> getThemeColor() async {
    if (Prefs().autoAdjustReadingTheme) {
      List<ReadTheme> themes = await selectThemes();
      final isDayMode =
          Theme.of(navigatorKey.currentContext!).brightness == Brightness.light;
      backgroundColor =
          isDayMode ? themes[0].backgroundColor : themes[1].backgroundColor;
      textColor = isDayMode ? themes[0].textColor : themes[1].textColor;
    } else {
      backgroundColor =Prefs().readTheme.backgroundColor;
      textColor = Prefs().readTheme.textColor;
    }
    setState(() {});
  }

  Future<void> setHandler(InAppWebViewController controller) async {
    String uri = Uri.encodeComponent(widget.book.fileFullPath);
    String url = 'http://localhost:${Server().port}/book/$uri';
    String initialCfi = widget.cfi ?? widget.book.lastReadPosition;

    await getThemeColor();

    webviewInitialVariable(
      controller,
      url,
      initialCfi,
      backgroundColor: backgroundColor,
      textColor: textColor,
    );

    controller.addJavaScriptHandler(
        handlerName: 'onLoadEnd',
        callback: (args) {
          widget.onLoadEnd();
        });

    controller.addJavaScriptHandler(
        handlerName: 'onRelocated',
        callback: (args) {
          Map<String, dynamic> location = args[0];
          if (cfi == location['cfi']) return;
          setState(() {
            cfi = location['cfi'];
            percentage = location['percentage'] ?? 0.0;
            chapterTitle = location['chapterTitle'] ?? '';
            chapterHref = location['chapterHref'] ?? '';
            chapterCurrentPage = location['chapterCurrentPage'];
            chapterTotalPages = location['chapterTotalPages'];
          });
          saveReadingProgress();
          readingPageKey.currentState?.resetAwakeTimer();
        });
    controller.addJavaScriptHandler(
        handlerName: 'onClick',
        callback: (args) {
          Map<String, dynamic> location = args[0];
          onClick(location);
        });
    controller.addJavaScriptHandler(
        handlerName: 'onSetToc',
        callback: (args) {
          List<dynamic> t = args[0];
          toc = t.map((i) => TocItem.fromJson(i)).toList();
        });
    controller.addJavaScriptHandler(
        handlerName: 'onSelectionEnd',
        callback: (args) {
          removeOverlay();
          Map<String, dynamic> location = args[0];
          String cfi = location['cfi'];
          String text = location['text'];
          bool footnote = location['footnote'];
          double x = location['pos']['point']['x'];
          double y = location['pos']['point']['y'];
          String dir = location['pos']['dir'];
          showContextMenu(context, x, y, dir, text, cfi, null, footnote);
        });
    controller.addJavaScriptHandler(
        handlerName: 'onAnnotationClick',
        callback: (args) {
          Map<String, dynamic> annotation = args[0];
          int id = annotation['annotation']['id'];
          String cfi = annotation['annotation']['value'];
          String note = annotation['annotation']['note'];
          double x = annotation['pos']['point']['x'];
          double y = annotation['pos']['point']['y'];
          String dir = annotation['pos']['dir'];
          showContextMenu(context, x, y, dir, note, cfi, id, false);
        });
    controller.addJavaScriptHandler(
      handlerName: 'onSearch',
      callback: (args) {
        Map<String, dynamic> search = args[0];
        setState(() {
          if (search['process'] != null) {
            searchProcess = search['process'].toDouble();
            _searchProgressController.add(searchProcess);
          } else {
            searchResult.add(SearchResultModel.fromJson(search));
            _searchResultController.add(searchResult);
          }
        });
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'renderAnnotations',
      callback: (args) {
        renderAnnotations(controller);
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onPushState',
      callback: (args) {
        Map<String, dynamic> state = args[0];
        canGoBack = state['canGoBack'];
        canGoForward = state['canGoForward'];
        if (!mounted) return;
        setState(() {
          showHistory = true;
        });
        Future.delayed(const Duration(seconds: 20), () {
          if (!mounted) return;
          setState(() {
            showHistory = false;
          });
        });
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onImageClick',
      callback: (args) {
        String image = args[0];
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ImageViewer(
                      image: image,
                      bookName: widget.book.title,
                    )));
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onFootnoteClose',
      callback: (args) {
        removeOverlay();
      },
    );
  }

  Future<void> onWebViewCreated(InAppWebViewController controller) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await InAppWebViewController.setWebContentsDebuggingEnabled(true);
    }
    webViewController = controller;
    setHandler(controller);
  }

  void removeOverlay() {
    if (contextMenuEntry == null || contextMenuEntry?.mounted == false) return;
    contextMenuEntry?.remove();
    contextMenuEntry = null;
  }

  void _handleKeyAndMouseEvents(KeyEvent event) {
    final nextPageEvent = [
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.pageDown,
      LogicalKeyboardKey.space,
    ];

    final prevPageEvent = [
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.pageUp,
    ];

    final appBarEvent = [
      LogicalKeyboardKey.enter,
    ];

    if (event is KeyDownEvent) {
      if (nextPageEvent.contains(event.logicalKey)) {
        nextPage();
      } else if (prevPageEvent.contains(event.logicalKey)) {
        prevPage();
      } else if (appBarEvent.contains(event.logicalKey)) {
        widget.showOrHideAppBarAndBottomBar(true);
      }
    }
  }

  void _handlePointerEvents(PointerEvent event) {
    if (event is PointerScrollEvent) {
      if (event.scrollDelta.dy > 0) {
        nextPage();
      } else {
        prevPage();
      }
    }
  }

  @override
  void initState() {
    book = widget.book;
    focusNode.requestFocus();

    contextMenu = ContextMenu(
      settings: ContextMenuSettings(hideDefaultSystemContextMenuItems: true),
      onCreateContextMenu: (hitTestResult) async {
        webViewController.evaluateJavascript(source: "showContextMenu()");
      },
      onHideContextMenu: () {
        removeOverlay();
      },
    );
    if (Prefs().openBookAnimation) {
      _animationController = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      _animation =
          Tween<double>(begin: 1.0, end: 0.0).animate(_animationController!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animationController!.forward();
      });
    }
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> saveReadingProgress() async {
    if (cfi == '') return;
    Book book = widget.book;
    book.lastReadPosition = cfi;
    book.readingPercentage = percentage;
    await updateBook(book);
    if (mounted) {
      ref.read(bookListProvider.notifier).refresh();
    }
  }

  @override
  void dispose() {
    super.dispose();
    _animationController?.dispose();
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      InAppWebViewController.clearAllCache();
    }
    saveReadingProgress();
    removeOverlay();
  }

  String indexHtmlPath =
      "http://localhost:${Server().port}/foliate-js/index.html";

  InAppWebViewSettings initialSettings = InAppWebViewSettings(
    supportZoom: false,
    transparentBackground: true,
    isInspectable: kDebugMode,
  );

  Widget readingInfoWidget() {
    if (chapterCurrentPage == 0) {
      return const SizedBox();
    }
    TextStyle textStyle = TextStyle(
      color: Color(int.parse('0x$textColor')).withAlpha(150),
      fontSize: 10,
    );

    Widget time = StreamBuilder(
        stream: Stream.periodic(const Duration(seconds: 1)),
        builder: (context, snapshot) {
          String currentTime = DateFormat('HH:mm').format(DateTime.now());
          return Text(currentTime, style: textStyle);
        });
    Battery battery = Battery();

    Widget batteryInfo = FutureBuilder(
        future: battery.batteryLevel,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Stack(alignment: Alignment.center, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 2, 2, 0),
                child: Text('${snapshot.data}',
                    style: TextStyle(
                      color: Color(int.parse('0x$textColor')),
                      fontSize: 9,
                    )),
              ),
              Icon(
                HeroIcons.battery_0,
                size: 27,
                color: Color(int.parse('0x$textColor')),
              ),
            ]);
          } else {
            return const SizedBox();
          }
        });

    Widget batteryAndTime = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        batteryInfo,
        const SizedBox(width: 5),
        time,
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeArea(
            child: Text(
                chapterCurrentPage == 1 ? widget.book.title : chapterTitle,
                style: textStyle),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              batteryAndTime,
              Text('$chapterCurrentPage/$chapterTotalPages', style: textStyle),
              Text('${(percentage * 100).toStringAsFixed(2)}%',
                  style: textStyle),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: focusNode,
      onKeyEvent: _handleKeyAndMouseEvents,
      child: Listener(
        onPointerSignal: (event) {
          _handlePointerEvents(event);
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              SizedBox.expand(
                child: InAppWebView(
                  webViewEnvironment: webViewEnvironment,
                  initialUrlRequest: URLRequest(url: WebUri(indexHtmlPath)),
                  initialSettings: initialSettings,
                  contextMenu: contextMenu,
                  onWebViewCreated: (controller) =>
                      onWebViewCreated(controller),
                  onConsoleMessage: (controller, consoleMessage) {
                    webviewConsoleMessage(controller, consoleMessage);
                  },
                ),
              ),
              readingInfoWidget(),
              if (showHistory)
                Positioned(
                  bottom: 30,
                  left: 0,
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (canGoBack)
                          IconButton(
                            onPressed: () {
                              backHistory();
                            },
                            icon: const Icon(Icons.arrow_back_ios),
                          ),
                        if (canGoForward)
                          IconButton(
                            onPressed: () {
                              forwardHistory();
                            },
                            icon: const Icon(Icons.arrow_forward_ios),
                          ),
                      ],
                    ),
                  ),
                ),
              if (Prefs().openBookAnimation)
                SizedBox.expand(
                  child: Prefs().openBookAnimation
                      ? IgnorePointer(
                          ignoring: true,
                          child: FadeTransition(
                              opacity: _animation!,
                              child: bookCover(context, widget.book)),
                        )
                      : bookCover(context, widget.book),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math';

import 'package:debounce_throttle/debounce_throttle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_tag_editor/suggestions_box_controller.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:super_tag_editor/utils/direction_helper.dart';
import 'package:super_tag_editor/widgets/validation_suggestion_item.dart';

import './tag_editor_layout_delegate.dart';
import './tag_layout.dart';

enum SuggestionButtonAlign {
  left,
  right,
}

typedef SuggestionBuilder<T> = Widget Function(
    BuildContext context,
    TagsEditorState<T> state,
    T data,
    int index,
    int lenght,
    bool highlight,
    String? suggestionValid);
typedef InputSuggestions<T> = FutureOr<List<T>> Function(String query);
typedef SearchSuggestions<T> = FutureOr<List<T>> Function();
typedef OnDeleteTagAction = Function();
typedef OnFocusTagAction = Function(bool focused);
typedef OnSelectOptionAction<T> = Function(T data);

/// A [Widget] for editing tag similar to Google's Gmail
/// email address input widget in the iOS app.
class TagEditor<T> extends StatefulWidget {
  const TagEditor(
      {required this.length,
      this.minTextFieldWidth = 160.0,
      this.tagSpacing = 4.0,
      required this.tagBuilder,
      required this.onTagChanged,
      required this.suggestionBuilder,
      required this.findSuggestions,
      Key? key,
      this.focusNode,
      this.hasAddButton = true,
      this.delimiters = const [],
      this.icon,
      this.enabled = true,
      this.controller,
      this.textStyle,
      this.inputDecoration = const InputDecoration(),
      this.keyboardType,
      this.textInputAction,
      this.textCapitalization = TextCapitalization.none,
      this.textAlign = TextAlign.start,
      this.textDirection,
      this.readOnly = false,
      this.autofocus = false,
      this.autocorrect = false,
      this.enableSuggestions = true,
      this.maxLines = 1,
      this.resetTextOnSubmitted = false,
      this.onSubmitted,
      this.inputFormatters,
      this.keyboardAppearance,
      this.suggestionsBoxMaxHeight,
      this.suggestionsBoxElevation,
      this.suggestionsBoxBackgroundColor,
      this.suggestionsBoxRadius,
      this.suggestionButtonAlign = SuggestionButtonAlign.left,
      this.suggestionButton,
      this.searchAllSuggestions,
      this.debounceDuration,
      this.activateSuggestionBox = true,
      this.cursorColor,
      this.backgroundColor,
      this.focusedBorderColor,
      this.enableBorderColor,
      this.borderRadius,
      this.borderSize,
      this.padding,
      this.suggestionPadding,
      this.autoDisposeFocusNode = true,
      this.suggestionMargin,
      this.onDeleteTagAction,
      this.onFocusTagAction,
      this.itemHighlightColor,
      this.useDefaultHighlight = true,
      this.enableFocusAfterEnter = true,
      this.onSelectOptionAction})
      : super(key: key);

  /// The number of tags currently shown.
  final int length;

  /// The minimum width that the `TextField` should take
  final double minTextFieldWidth;

  /// The spacing between each tag
  final double tagSpacing;

  /// Builder for building the tags, this usually use Flutter's Material `Chip`.
  final Widget Function(BuildContext, int) tagBuilder;

  /// Show the add button to the right.
  final bool hasAddButton;

  /// The icon for the add button enabled with `hasAddButton`.
  final IconData? icon;

  /// Callback for when the tag changed. Use this to get the new tag and add
  /// it to the state.
  final ValueChanged<String> onTagChanged;

  /// When the string value in this `delimiters` is found, a new tag will be
  /// created and `onTagChanged` is called.
  final List<String> delimiters;

  /// Reset the TextField when `onSubmitted` is called
  /// this is default to `false` because when the form is submitted
  /// usually the outstanding value is just used, but this option is here
  /// in case you want to reset it for any reasons (like converting the
  /// outstanding value to tag).
  final bool resetTextOnSubmitted;

  /// Called when the user are done editing the text in the [TextField]
  /// Use this to get the outstanding text that aren't converted to tag yet
  /// If no text is entered when this is called an empty string will be passed.
  final ValueChanged<String>? onSubmitted;

  /// Focus node for checking if the [TextField] is focused.
  final FocusNode? focusNode;

  final OnDeleteTagAction? onDeleteTagAction;
  final OnFocusTagAction? onFocusTagAction;

  /// [TextField]'s properties.
  ///
  /// Please refer to [TextField] documentation.
  final TextEditingController? controller;
  final bool enabled;
  final TextStyle? textStyle;
  final InputDecoration inputDecoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final bool autofocus;
  final bool autocorrect;
  final bool enableSuggestions;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;
  final Brightness? keyboardAppearance;
  final Color? cursorColor;
  final Color? backgroundColor;
  final Color? focusedBorderColor;
  final Color? enableBorderColor;
  final double? borderRadius;
  final double? borderSize;
  final EdgeInsets? padding;
  final bool autoDisposeFocusNode;
  final bool enableFocusAfterEnter;

  /// [SuggestionBox]'s properties.
  final double? suggestionsBoxMaxHeight;
  final double? suggestionsBoxElevation;
  final SuggestionBuilder<T> suggestionBuilder;
  final InputSuggestions<T> findSuggestions;
  final SearchSuggestions<T>? searchAllSuggestions;
  final OnSelectOptionAction<T>? onSelectOptionAction;
  final Color? suggestionsBoxBackgroundColor;
  final Color? itemHighlightColor;
  final double? suggestionsBoxRadius;
  final SuggestionButtonAlign suggestionButtonAlign;
  final Widget? suggestionButton;
  final Duration? debounceDuration;
  final bool activateSuggestionBox;
  final EdgeInsets? suggestionMargin;
  final EdgeInsets? suggestionPadding;
  final bool useDefaultHighlight;

  @override
  TagsEditorState<T> createState() => TagsEditorState<T>();
}

class TagsEditorState<T> extends State<TagEditor<T>> {
  /// A controller to keep value of the [TextField].
  late TextEditingController _textFieldController;
  late TextDirection _textDirection;

  /// A state variable for checking if new text is enter.
  var _previousText = '';

  /// A state for checking if the [TextFiled] has focus.
  var _isFocused = false;

  /// Focus node for checking if the [TextField] is focused.
  late FocusNode _focusNode;
  late FocusNode _focusNodeKeyboard;

  StreamController<List<T>?>? _suggestionsStreamController;
  SuggestionsBoxController? _suggestionsBoxController;
  final _layerLink = LayerLink();
  List<T>? _suggestions;
  int _searchId = 0;
  int _countBackspacePressed = 0;
  Debouncer<String>? _deBouncer;
  final ValueNotifier<int> _highlightedOptionIndex = ValueNotifier<int>(0);
  final ValueNotifier<String?> _validationSuggestionItemNotifier =
      ValueNotifier<String?>(null);

  RenderBox? get renderBox => context.findRenderObject() as RenderBox?;

  @override
  void initState() {
    super.initState();
    _textFieldController = (widget.controller ?? TextEditingController());
    _textDirection = widget.textDirection ?? TextDirection.ltr;
    _focusNodeKeyboard = FocusNode()..addListener(_onFocusKeyboardChanged);
    _focusNode = (widget.focusNode ?? FocusNode())
      ..addListener(_onFocusChanged);

    if (widget.activateSuggestionBox) _initializeSuggestionBox();
  }

  @override
  void dispose() {
    if (widget.autoDisposeFocusNode || widget.focusNode == null) {
      _focusNode.removeListener(_onFocusChanged);
      _focusNode.dispose();
    }
    _suggestionsStreamController?.close();
    _suggestionsBoxController?.close();
    _focusNodeKeyboard.removeListener(_onFocusKeyboardChanged);
    _focusNodeKeyboard.dispose();
    _highlightedOptionIndex.dispose();
    _validationSuggestionItemNotifier.dispose();
    _deBouncer?.cancel();
    super.dispose();
  }

  void _updateHighlight(int newIndex) {
    _highlightedOptionIndex.value =
        _suggestions?.isNotEmpty == true ? newIndex % _suggestions!.length : 0;
  }

  void _highlightPreviousOption() {
    _updateHighlight(_highlightedOptionIndex.value - 1);
  }

  void _highlightNextOption() {
    _updateHighlight(_highlightedOptionIndex.value + 1);
  }

  void _selectOption() {
    final currentHighlightIndex = _highlightedOptionIndex.value;
    if (_suggestions?.isNotEmpty == true &&
        currentHighlightIndex >= 0 &&
        currentHighlightIndex < _suggestions!.length) {
      final optionSelected = _suggestions![currentHighlightIndex];
      widget.onSelectOptionAction?.call(optionSelected);
      resetTextField();
      closeSuggestionBox();
    }
  }

  void _updateValidationSuggestionItem(String? value) {
    _validationSuggestionItemNotifier.value = value;
  }

  void _initializeSuggestionBox() {
    _deBouncer = Debouncer<String>(
        widget.debounceDuration ?? const Duration(milliseconds: 300),
        initialValue: '');

    _deBouncer?.values.listen(_onSearchChanged);

    _suggestionsBoxController = SuggestionsBoxController(context);
    _suggestionsStreamController = StreamController<List<T>?>.broadcast();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _createOverlayEntry();
    });
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      widget.onFocusTagAction?.call(false);
      _countBackspacePressed = 0;
      _scrollToVisible();
      _suggestionsBoxController?.open();
    } else {
      _suggestionsBoxController?.close();
    }

    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  void _onFocusKeyboardChanged() {
    if (_focusNodeKeyboard.hasFocus) {
      widget.onFocusTagAction?.call(true);
      _countBackspacePressed = 1;
    } else {
      widget.onFocusTagAction?.call(false);
      _countBackspacePressed = 0;
    }
  }

  void _createOverlayEntry() {
    _suggestionsBoxController?.overlayEntry = OverlayEntry(
      builder: (context) {
        if (renderBox != null) {
          final size = renderBox!.size;
          final renderBoxOffset = renderBox!.localToGlobal(Offset.zero);
          final topAvailableSpace = renderBoxOffset.dy;
          final mq = MediaQuery.of(context);
          final bottomAvailableSpace = mq.size.height -
              mq.viewInsets.bottom -
              renderBoxOffset.dy -
              size.height;
          var suggestionBoxHeight =
              max(topAvailableSpace, bottomAvailableSpace);
          if (null != widget.suggestionsBoxMaxHeight) {
            suggestionBoxHeight =
                min(suggestionBoxHeight, widget.suggestionsBoxMaxHeight!);
          }
          final showTop = topAvailableSpace > bottomAvailableSpace;
          final compositedTransformFollowerOffset =
              showTop ? Offset(0, -size.height) : Offset.zero;

          return StreamBuilder<List<T>?>(
            stream: _suggestionsStreamController?.stream,
            initialData: _suggestions,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                final suggestionsListView = TextFieldTapRegion(
                  child: PointerInterceptor(
                    child: AutocompleteHighlightedOption(
                      highlightIndexNotifier: _highlightedOptionIndex,
                      child: ValidationSuggestionItem(
                        validationNotifier: _validationSuggestionItemNotifier,
                        child: Padding(
                          padding: widget.suggestionMargin ?? EdgeInsets.zero,
                          child: Material(
                            elevation: widget.suggestionsBoxElevation ?? 20,
                            borderRadius: BorderRadius.circular(
                                widget.suggestionsBoxRadius ?? 20),
                            color: widget.suggestionsBoxBackgroundColor ??
                                Colors.white,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                  widget.suggestionsBoxRadius ?? 20),
                              child: Container(
                                  decoration: BoxDecoration(
                                      color: widget
                                              .suggestionsBoxBackgroundColor ??
                                          Colors.white,
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(
                                              widget.suggestionsBoxRadius ??
                                                  0))),
                                  constraints: BoxConstraints(
                                      maxHeight: suggestionBoxHeight),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    padding: widget.suggestionPadding ??
                                        EdgeInsets.zero,
                                    itemCount: snapshot.data!.length,
                                    itemBuilder: (context, index) {
                                      if (_suggestions != null &&
                                          _suggestions?.isNotEmpty == true) {
                                        final item = _suggestions![index];
                                        final highlight =
                                            AutocompleteHighlightedOption.of(
                                                    context) ==
                                                index;
                                        final suggestionValid =
                                            ValidationSuggestionItem.of(
                                                context);

                                        if (!widget.useDefaultHighlight) {
                                          return widget.suggestionBuilder(
                                              context,
                                              this,
                                              item,
                                              index,
                                              snapshot.data!.length,
                                              highlight,
                                              suggestionValid);
                                        } else {
                                          return Container(
                                              color: highlight
                                                  ? widget.itemHighlightColor ??
                                                      Theme.of(context)
                                                          .focusColor
                                                  : null,
                                              child: widget.suggestionBuilder(
                                                  context,
                                                  this,
                                                  item,
                                                  index,
                                                  snapshot.data!.length,
                                                  highlight,
                                                  suggestionValid));
                                        }
                                      } else {
                                        return Container();
                                      }
                                    },
                                  )),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                return Positioned(
                  width: size.width,
                  child: CompositedTransformFollower(
                    link: _layerLink,
                    showWhenUnlinked: false,
                    offset: compositedTransformFollowerOffset,
                    child: !showTop
                        ? suggestionsListView
                        : FractionalTranslation(
                            translation: const Offset(0, -1),
                            child: suggestionsListView,
                          ),
                  ),
                );
              }
              return Container();
            },
          );
        }
        return Container();
      },
    );
  }

  void _onTagChanged(String string) {
    if (string.isNotEmpty) {
      widget.onTagChanged(string);
      resetTextField();
    }
  }

  /// This function is still ugly, have to fix this later
  void _onTextFieldChange(String string) {
    if (string != _previousText) {
      _deBouncer?.value = string;
    }

    final previousText = _previousText;
    _previousText = string;

    if (string.isEmpty || widget.delimiters.isEmpty) {
      return;
    }

    // Do not allow the entry of the delimters, this does not account for when
    // the text is set with `TextEditingController` the behaviour of TextEditingContoller
    // should be controller by the developer themselves
    if (string.length == 1 && widget.delimiters.contains(string)) {
      resetTextField();
      return;
    }

    if (string.length > previousText.length) {
      // Add case
      final newChar = string[string.length - 1];
      if (widget.delimiters.contains(newChar)) {
        final targetString = string.substring(0, string.length - 1);
        if (targetString.isNotEmpty) {
          _onTagChanged(targetString);
        }
      }
    }
  }

  void _onSearchChanged(String value) async {
    final localId = ++_searchId;
    final results = await widget.findSuggestions(value);
    if (_searchId == localId && mounted) {
      setState(() => _suggestions = results);
    }
    _updateHighlight(0);
    _updateValidationSuggestionItem(value);
    _suggestionsStreamController?.add(_suggestions ?? []);
    _suggestionsBoxController?.open();
  }

  void toggleSuggestionBox() async {
    if (_suggestionsBoxController?.isOpened == true) {
      closeSuggestionBox();
    } else {
      openSuggestionBox();
    }
  }

  void openSuggestionBox() async {
    if (widget.searchAllSuggestions != null) {
      final localId = ++_searchId;
      final results = await widget.searchAllSuggestions!();
      if (_searchId == localId && mounted) {
        setState(() => _suggestions = results);
      }
      _updateHighlight(0);
      _updateValidationSuggestionItem(null);
      _suggestionsStreamController?.add(_suggestions ?? []);
      _suggestionsBoxController?.open();
    }
  }

  void closeSuggestionBox({bool isClearData = true}) {
    if (isClearData) {
      _suggestions = null;
      _suggestionsStreamController?.add([]);
    }
    _updateHighlight(0);
    _updateValidationSuggestionItem(null);
    _suggestionsBoxController?.close();
  }

  void _scrollToVisible() {
    Future.delayed(const Duration(milliseconds: 300), () {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final renderBox = context.findRenderObject() as RenderBox;
        await Scrollable.of(context).position.ensureVisible(renderBox);
      });
    });
  }

  void _onSubmitted(String string) {
    if (_suggestions?.isNotEmpty == true &&
        _suggestionsBoxController?.isOpened == true) {
      _selectOption();
    } else {
      widget.onSubmitted?.call(string);
      if (widget.resetTextOnSubmitted) {
        resetTextField();
      }
    }
    if (widget.enableFocusAfterEnter) {
      _focusNode.requestFocus();
    }
  }

  void resetTextField() {
    _textFieldController.text = '';
    _previousText = '';
    _updateHighlight(0);
    _updateValidationSuggestionItem(null);
  }

  void _onKeyboardBackspaceListener() async {
    if (_textFieldController.text.isEmpty && widget.length > 0) {
      _countBackspacePressed++;

      if (_countBackspacePressed == 1) {
        _focusNode.unfocus();
        _focusNodeKeyboard.requestFocus();
      } else if (_countBackspacePressed >= 2) {
        widget.onDeleteTagAction?.call();
        if (widget.length > 1) {
          _countBackspacePressed = 1;
        } else {
          _countBackspacePressed = 0;
          _focusNodeKeyboard.unfocus();
          _focusNode.requestFocus();
        }
      }
    } else {
      _focusNodeKeyboard.unfocus();
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final decoration = widget.hasAddButton
        ? widget.inputDecoration.copyWith(
            suffixIcon: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                _onTagChanged(_textFieldController.text);
              },
              child: Icon(widget.icon ?? Icons.add),
            ),
          )
        : widget.inputDecoration;

    final tagEditorArea = Container(
      padding: widget.padding ?? EdgeInsets.zero,
      decoration: BoxDecoration(
          borderRadius:
              BorderRadius.all(Radius.circular(widget.borderRadius ?? 0)),
          border: Border.all(
              width: widget.borderSize ?? (_isFocused ? 1 : 0.5),
              color: _isFocused
                  ? widget.focusedBorderColor ?? Colors.transparent
                  : widget.enableBorderColor ?? Colors.transparent),
          color: widget.backgroundColor ?? Colors.transparent),
      child: TagLayout(
        delegate: TagEditorLayoutDelegate(
          length: widget.length,
          minTextFieldWidth: widget.minTextFieldWidth,
          spacing: widget.tagSpacing,
        ),
        children: [
          ...List<Widget>.generate(
            widget.length,
            (index) => LayoutId(
              id: TagEditorLayoutDelegate.getTagId(index),
              child: widget.tagBuilder(context, index),
            ),
          ),
          LayoutId(
            id: TagEditorLayoutDelegate.textFieldId,
            child: RawKeyboardListener(
              focusNode: _focusNodeKeyboard,
              onKey: (event) {
                if (event is RawKeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.backspace) {
                  _onKeyboardBackspaceListener();
                } else if (event is RawKeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  _highlightNextOption();
                } else if (event is RawKeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  _highlightPreviousOption();
                }
              },
              child: TextField(
                style: widget.textStyle,
                focusNode: _focusNode,
                enabled: widget.enabled,
                controller: _textFieldController,
                keyboardType: widget.keyboardType,
                keyboardAppearance: widget.keyboardAppearance,
                textCapitalization: widget.textCapitalization,
                textInputAction: widget.textInputAction,
                cursorColor: widget.cursorColor,
                autocorrect: widget.autocorrect,
                textAlign: widget.textAlign,
                textDirection: _textDirection,
                readOnly: widget.readOnly,
                autofocus: widget.autofocus,
                enableSuggestions: widget.enableSuggestions,
                maxLines: widget.maxLines,
                decoration: decoration,
                onChanged: (value) {
                  _onTextFieldChange.call(value);
                  if (value.isNotEmpty) {
                    final directionByText =
                        DirectionHelper.getDirectionByEndsText(value);
                    if (directionByText != _textDirection) {
                      setState(() {
                        _textDirection = directionByText;
                      });
                    }
                  }
                },
                onSubmitted: _onSubmitted,
                inputFormatters: widget.inputFormatters,
              ),
            ),
          )
        ],
      ),
    );

    Widget? itemChild;

    if (widget.suggestionButton == null) {
      itemChild = tagEditorArea;
    } else {
      itemChild = Row(
        children: <Widget>[
          if (widget.suggestionButton != null &&
              widget.suggestionButtonAlign == SuggestionButtonAlign.left)
            _provideSuggestionButton(this),
          Expanded(child: tagEditorArea),
          if (widget.suggestionButton != null &&
              widget.suggestionButtonAlign == SuggestionButtonAlign.right)
            _provideSuggestionButton(this),
        ],
      );
    }

    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (SizeChangedLayoutNotification val) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          _suggestionsBoxController?.overlayEntry?.markNeedsBuild();
        });
        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: Column(
          children: <Widget>[
            itemChild,
            CompositedTransformTarget(
              link: _layerLink,
              child: Container(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _provideSuggestionButton(TagsEditorState<T> state) => Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: IconButton(
        icon: widget.suggestionButton!,
        splashRadius: 20,
        onPressed: () => toggleSuggestionBox(),
      ));
}

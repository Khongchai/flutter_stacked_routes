import 'package:dynamic_routing/stacked_routes/page_dll_data.dart';
import 'package:flutter/material.dart';

abstract class StackedRoutesDisposer {
  /// This is the only method that is allowed to be called repeatedly, even when it does nothing.
  ///
  /// The reason being that sometimes, you might want to both dispose the references when the Initiator widget's state
  /// is disposed and when the callback is called, but you are not sure which one should happen first. The fix is to just call
  /// the dispose method in both places (or more).
  void dispose();
}

abstract class InitiatorNavigator {
  /// Call this function to load a list of pages to be pushed on to the stack.
  ///
  /// lastPageCallback is what pushNext will do for the final page in the array,
  /// for example, show a dialog box and then push another page or go back to the main page with the Navigator.
  void initializeNewStack(List<Widget> pages,
      {Function(BuildContext context)? lastPageCallback});

  /// Push the first page in the stack
  ///
  /// This is called in the page before the first page included in the navigation stack.
  void pushFirst(BuildContext context);

  List<Widget> getLoadedPages();
}

abstract class ParticipatorNavigator {
  /// Returns the page widget that belongs to the current route
  int? getCurrentWidgetHash();

  /// Push the next page in the stack
  ///
  /// currentPage is needed to obtain the correct previous and next route in the stack.
  ///
  /// ex. pushNext(context, currentPage: widget);
  void pushNext(BuildContext context, {required Widget currentPage});

  /// Pop the current page from the stack
  ///
  /// Prefer this over Navigator.of(context).pop for all participators widget.
  void popCurrent(BuildContext context, {required Widget currentPage});

  bool pushNextOfLastPageCalled();
}

/// Let's say that your login flow requires the user to fill in their information and the form is split into 5 pages.
/// However, some of the information in those 5 pages can also be pre-obtained through other means, which would render
/// some of the pages in this flow unnecessary.
///
/// The solution would be to have some sort of navigator that we can just say push
/// conditionally push some of these set of pages in some specific order.
///
/// ## Instructions:
///
/// First, we'd need to mark the participating page with the DynamicRoutesParticipator mixin.
/// This would give that component access to the dynamicRoutesParticipator object that is tied to the
/// scope of the initiator page which we'll mark with the DynamicRoutesInitiator.
///
/// For the page directly before the flow:
///
/// ```dart
/// class SomeWidget extends StatefulWidget with DynamicRoutesInitiator{
///  //...some code
/// }
///
/// class _SomeWidgetState extends State<Page4> {
///   void onButtonPressed() {
///   const isPage4Required = calculateIfPage4IsRequired();
///
///     dynamicRoutesInitiator.initializeRoutes(
///       [
///         Page1(),
///         Page2(),
///         Page3(),
///         if (isPage4Required) Page4(),
///         Page5(),
///       ],
///       lastPageCallback: (context) {
///         // Do something; maybe return to homepage.
///       }
///     );
///   }
///
///   //...some code
/// }
/// ```
///
/// And then in the pages that will be included within the stack
///
/// ```dart
/// class SomeWidget extends StatefulWidget with StackedRoutesParticipator{
///   //...some code
/// }
///
/// class _SomeWidgetState extends State<Page4> {
///   void onButtonPressed() => widget.stackedRoutesNavigator.pushNext(context, currentPage: widget);
///    //...build methods and whatever
/// }
///```
///
/// We can garbage collect the scoped-singleton instance by calling the navigator's dispose method in the
/// initiator page's dispose method.
///
/// ```dart
/// @override
/// dispose(){
///   stackedRoutesNavigator.dispose();
///
///   super.dispose();
/// }
/// ```
abstract class StackedRoutesNavigator
    implements InitiatorNavigator, ParticipatorNavigator {
  /// A map between the widget's hash and the doubly-linked list data it belongs to
  late Map<int, PageDLLData> _pageDataMap = {};

  /// Kept primarily for debugging purposes
  int? _currentPageHash;

  /// Use as a safeguard to prevent this being used before the states are loaded.
  bool _isStackLoaded = false;

  bool _isPostLastPage = false;

  Function(BuildContext context)? _lastPageCallback;
}

//TODO also added a mechanism for passing information
class StackedRoutesNavigatorImpl extends StackedRoutesNavigator {
  @override
  List<Widget> getLoadedPages() {
    return _pageDataMap.values.map((e) => e.currentPage).toList();
  }

  @override
  int? getCurrentWidgetHash() {
    return _currentPageHash;
  }

  @override
  initializeNewStack(List<Widget> pages,
      {Function(BuildContext context)? lastPageCallback}) {
    _lastPageCallback = lastPageCallback;
    _isStackLoaded = true;
    _pageDataMap = _generatePageStates(pages: pages);
  }

  Map<int, PageDLLData> _generatePageStates({required List<Widget> pages}) {
    final Map<int, PageDLLData> pageRoutes = {};

    _currentPageHash = pages.first.hashCode;

    for (int i = 0; i < pages.length; i++) {
      final previousPage = i - 1 < 0 ? null : pages[i - 1];
      final nextPage = i + 1 >= pages.length ? null : pages[i + 1];
      final currentPage = pages[i];

      final currentPageStates = PageDLLData(
        previousPage: previousPage,
        currentPage: currentPage,
        nextPage: nextPage,
      );

      pageRoutes[currentPage.hashCode] = currentPageStates;
    }

    return pageRoutes;
  }

  @override
  void pushNext(BuildContext context, {required Widget currentPage}) {
    final currentPageState = _pageDataMap[currentPage.hashCode];

    assert(currentPageState != null,
        "The widget provided was not included in the initial array when loadStack() was called.");
    assert(_isStackLoaded,
        "the loadStack() method should be called first before this can be used.");
    assert(_currentPageHash != null,
        "Call pushFirst(context) before the first page of this flow to begin stacked navigation");

    if (currentPageState!.isLastPage()) {
      _lastPageCallback?.call(context);

      _isPostLastPage = true;
    } else {
      _currentPageHash = currentPageState.nextPage.hashCode;
      Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => currentPageState.nextPage!));
    }
  }

  @override
  void pushFirst(BuildContext context) {
    assert(_isStackLoaded,
        "the loadStack() method should be called first before this can be used.");

    final firstPage = _pageDataMap.values.first;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => firstPage.currentPage));
  }

  @override
  void popCurrent(BuildContext context, {required Widget currentPage}) {
    final _currentPage = _pageDataMap[currentPage.hashCode];

    assert(_currentPage != null,
        "The page this method is called in was not included in the array when loadStack() was called");
    assert(_isStackLoaded,
        "the loadStack() method should be called first before this can be used.");
    assert(_currentPageHash != null,
        "Call pushFirst(context) before the first page of this flow to begin stacked navigation");

    _currentPageHash = _currentPage!.previousPage.hashCode;

    Navigator.pop(context);
  }

  @override
  bool pushNextOfLastPageCalled() {
    return _isPostLastPage;
  }
}

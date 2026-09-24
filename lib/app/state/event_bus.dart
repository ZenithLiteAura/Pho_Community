import 'package:event_bus/event_bus.dart';

//Bus初始化
EventBus eventBus = EventBus();

class LocalRefreshEvent {
  LocalRefreshEvent({this.refreshUnSync = true});
  bool refreshUnSync = true;
}

class RemoteRefreshEvent {
  RemoteRefreshEvent({this.refreshUnSync = true});
  bool refreshUnSync = true;
}

class FinishGettingLocal {
  FinishGettingLocal();
}

class FinishGettingRemote {
  FinishGettingRemote();
}

class BuyProEvent {
  BuyProEvent();
}

class IAPPendingEvent {
  IAPPendingEvent();
}

class IAPErrorEvent {
  IAPErrorEvent(
    this.err,
  );
  String? err;
}

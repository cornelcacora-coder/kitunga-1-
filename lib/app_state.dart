import 'package:flutter/material.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/api_requests/api_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flutter_flow/flutter_flow_util.dart';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {
    prefs = await SharedPreferences.getInstance();
    _safeInit(() {
      _orderStatus = prefs.getString('ff_orderStatus') ?? _orderStatus;
    });
    _safeInit(() {
      _totalCart = prefs.getDouble('ff_totalCart') ?? _totalCart;
    });
    _safeInit(() {
      _GrandTotalCart = prefs.getDouble('ff_GrandTotalCart') ?? _GrandTotalCart;
    });
    _safeInit(() {
      _cartitems = prefs
              .getStringList('ff_cartitems')
              ?.map((path) => path.ref)
              .toList() ??
          _cartitems;
    });
    _safeInit(() {
      _valueToClear = prefs.getString('ff_valueToClear') ?? _valueToClear;
    });
    _safeInit(() {
      _orderReferenceUnique =
          prefs.getString('ff_orderReferenceUnique') ?? _orderReferenceUnique;
    });
    _safeInit(() {
      _isSameOrder = prefs.getBool('ff_isSameOrder') ?? _isSameOrder;
    });
  }

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  late SharedPreferences prefs;

  /// Frais de livraison fixe (connu et fixé à l'avance)
  double _fixedShippingFee = 2000.0;
  double get fixedShippingFee => _fixedShippingFee;
  set fixedShippingFee(double value) {
    _fixedShippingFee = value;
  }

  /// Payment by MYN Mobile Money to purchase somethings.
  bool _MoMoPay = false;
  bool get MoMoPay => _MoMoPay;
  set MoMoPay(bool value) {
    _MoMoPay = value;
  }

  /// The order status for progressing (track order movemet inside application)
  String _orderStatus = '';
  String get orderStatus => _orderStatus;
  set orderStatus(String value) {
    _orderStatus = value;
    prefs.setString('ff_orderStatus', value);
  }

  /// The totale value of all article inside the cart (to make order)
  double _totalCart = 0.0;
  double get totalCart => _totalCart;
  set totalCart(double value) {
    _totalCart = value;
    prefs.setDouble('ff_totalCart', value);
  }

  /// The grand total for the cart (to calculate Total with static delivery
  /// fees)
  double _GrandTotalCart = 0.0;
  double get GrandTotalCart => _GrandTotalCart;
  set GrandTotalCart(double value) {
    _GrandTotalCart = value;
    prefs.setDouble('ff_GrandTotalCart', value);
  }

  /// Listed item in the cart
  List<DocumentReference> _cartitems = [];
  List<DocumentReference> get cartitems => _cartitems;
  set cartitems(List<DocumentReference> value) {
    _cartitems = value;
    prefs.setStringList('ff_cartitems', value.map((x) => x.path).toList());
  }

  void addToCartitems(DocumentReference value) {
    cartitems.add(value);
    prefs.setStringList('ff_cartitems', _cartitems.map((x) => x.path).toList());
  }

  void removeFromCartitems(DocumentReference value) {
    cartitems.remove(value);
    prefs.setStringList('ff_cartitems', _cartitems.map((x) => x.path).toList());
  }

  void removeAtIndexFromCartitems(int index) {
    cartitems.removeAt(index);
    prefs.setStringList('ff_cartitems', _cartitems.map((x) => x.path).toList());
  }

  void updateCartitemsAtIndex(
    int index,
    DocumentReference Function(DocumentReference) updateFn,
  ) {
    cartitems[index] = updateFn(_cartitems[index]);
    prefs.setStringList('ff_cartitems', _cartitems.map((x) => x.path).toList());
  }

  void insertAtIndexInCartitems(int index, DocumentReference value) {
    cartitems.insert(index, value);
    prefs.setStringList('ff_cartitems', _cartitems.map((x) => x.path).toList());
  }

  String _valueToClear = '';
  String get valueToClear => _valueToClear;
  set valueToClear(String value) {
    _valueToClear = value;
    prefs.setString('ff_valueToClear', value);
  }

  /// this is the main order reference for unique order table.
  ///
  /// this is using to follow the orderItems  for a giving cart.
  String _orderReferenceUnique = '';
  String get orderReferenceUnique => _orderReferenceUnique;
  set orderReferenceUnique(String value) {
    _orderReferenceUnique = value;
    prefs.setString('ff_orderReferenceUnique', value);
  }

  /// if the user add new product inside the same cart then create one order.
  bool _isSameOrder = false;
  bool get isSameOrder => _isSameOrder;
  set isSameOrder(bool value) {
    _isSameOrder = value;
    prefs.setBool('ff_isSameOrder', value);
  }
}

void _safeInit(Function() initializeField) {
  try {
    initializeField();
  } catch (_) {}
}

Future _safeInitAsync(Function() initializeField) async {
  try {
    await initializeField();
  } catch (_) {}
}

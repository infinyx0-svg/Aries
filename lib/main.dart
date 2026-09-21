import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const AriesApp());

class Venta {
  final String fecha;
  final String hora;
  final String seccion;
  final String operador;
  final String detalle;
  final int cantidad;
  final double monto;
  final double unit;

  Venta({
    required this.fecha,
    this.hora = '',
    required this.seccion,
    this.operador = '',
    this.detalle = '',
    required this.cantidad,
    required this.monto,
    this.unit = 0,
  });

  Map<String, dynamic> toJson() => {
    'fecha': fecha,
    'hora': hora,
    'seccion': seccion,
    'operador': operador,
    'detalle': detalle,
    'cantidad': cantidad,
    'monto': monto,
    'unit': unit,
  };

  factory Venta.fromJson(Map<String, dynamic> j) => Venta(
    fecha: (j['fecha'] ?? '') as String,
    hora: (j['hora'] ?? '') as String,
    seccion: (j['seccion'] ?? '') as String,
    operador: (j['operador'] ?? '') as String,
    detalle: (j['detalle'] ?? '') as String,
    cantidad: (j['cantidad'] as num? ?? 0).toInt(),
    monto: (j['monto'] as num? ?? 0).toDouble(),
    unit: (j['unit'] as num? ?? 0).toDouble(),
  );
}

class KaChing {
  static final AudioPlayer _player = AudioPlayer();
  static Uint8List? _wav;

  static void _str(ByteData b, int o, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  static Uint8List _build() {
    const sr = 22050;
    final n = (sr * 0.45).toInt();
    final rnd = Random(7);
    final pcm = Int16List(n);
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      double s = 0;
      if (t < 0.06) {
        s += (rnd.nextDouble() * 2 - 1) * 0.5 * (1 - t / 0.06);
      }
      s += sin(2 * pi * 1245 * t) * exp(-6 * t) * 0.5;
      final t2 = t - 0.09;
      if (t2 > 0) {
        s += sin(2 * pi * 1865 * t2) * exp(-5 * t2) * 0.45;
      }
      pcm[i] = (s.clamp(-1.0, 1.0) * 32000).toInt();
    }
    final out = ByteData(44 + n * 2);
    _str(out, 0, 'RIFF');
    out.setUint32(4, 36 + n * 2, Endian.little);
    _str(out, 8, 'WAVE');
    _str(out, 12, 'fmt ');
    out.setUint32(16, 16, Endian.little);
    out.setUint16(20, 1, Endian.little);
    out.setUint16(22, 1, Endian.little);
    out.setUint32(24, sr, Endian.little);
    out.setUint32(28, sr * 2, Endian.little);
    out.setUint16(32, 2, Endian.little);
    out.setUint16(34, 16, Endian.little);
    _str(out, 36, 'data');
    out.setUint32(40, n * 2, Endian.little);
    for (var i = 0; i < n; i++) {
      out.setInt16(44 + i * 2, pcm[i], Endian.little);
    }
    return out.buffer.asUint8List();
  }

  static Future<void> play() async {
    try {
      _wav ??= _build();
      await _player.stop();
      await _player.play(BytesSource(_wav!));
    } catch (e) {
      // sin sonido la caja sigue funcionando
    }
  }
}

class AriesApp extends StatelessWidget {
  const AriesApp({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
    title: 'Aries',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF0B0F12),
      colorScheme: const ColorScheme.dark(primary: Color(0xFF2DE0C0)),
    ),
    home: const Home(),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  int tab = 0;
  List<Venta> ventas = [];
  int racha = 0;
  double cierreSemana = 0;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  static const neon = Color(0xFF2DE0C0);
  static const oro = Color(0xFFFFC800);
  static const tigo = Color(0xFF2563EB);
  static const viva = Color(0xFF22C55E);
  static const entel = Color(0xFF67E8F9);
  static const peligro = Color(0xFFE63946);
  static const llamadas = Color(0xFFB388FF);
  static const bebidas = Color(0xFFFF9F1C);
  static const prod = Color(0xFFFF5D8F);
  static const oscuro = Color(0xFF151B21);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String _hoy() => DateTime.now().toIso8601String().substring(0, 10);

  String _ahora() {
    final n = DateTime.now();
    return n.hour.toString().padLeft(2, '0') +
        ':' +
        n.minute.toString().padLeft(2, '0');
  }

  String _lunesDe(DateTime d) {
    final w = d.weekday - 1;
    return d.subtract(Duration(days: w)).toIso8601String().substring(0, 10);
  }

  String _fechaCorta(DateTime n) {
    const dias = [
      'lunes',
      'martes',
      'miercoles',
      'jueves',
      'viernes',
      'sabado',
      'domingo',
    ];
    const meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return dias[n.weekday - 1] +
        ' ' +
        n.day.toString() +
        ' ' +
        meses[n.month - 1];
  }

  String _fechaDe(String f) =>
      _fechaCorta(DateTime.tryParse(f) ?? DateTime.now());

  String bs(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  double _unitDe(Venta v) =>
      v.unit > 0 ? v.unit : (v.cantidad > 0 ? v.monto / v.cantidad : v.monto);

  Color _colorOp(String o) => o == 'TIGO' ? tigo : (o == 'VIVA' ? viva : entel);

  Color _colorDe(Venta v) {
    if (v.seccion == 'TARJETAS') {
      if (v.operador == 'TIGO') return tigo;
      if (v.operador == 'VIVA') return viva;
      if (v.operador == 'ENTEL') return entel;
      return neon;
    }
    if (v.seccion == 'LLAMADAS') return llamadas;
    if (v.seccion == 'BEBIDAS') return bebidas;
    return prod;
  }

  Color _colorSeccion(int t) =>
      t == 1 ? neon : (t == 2 ? llamadas : (t == 3 ? bebidas : prod));

  void _calcRacha() {
    racha = 0;
    var d = DateTime.now();
    while (ventas.any((v) => v.fecha == d.toIso8601String().substring(0, 10))) {
      racha++;
      d = d.subtract(const Duration(days: 1));
    }
  }

  Future<void> _cargar() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList('ventas') ?? [];
    ventas = raw
        .map((e) => Venta.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();

    final lunesHoy = _lunesDe(DateTime.now());
    final lunesGuardado = p.getString('lunes') ?? lunesHoy;
    if (lunesGuardado != lunesHoy) {
      cierreSemana = ventas.fold<double>(0, (s, v) => s + v.monto);
      ventas = [];
      await p.setString('lunes', lunesHoy);
      await p.setDouble('cierre', cierreSemana);
      await _guardar();
    } else {
      cierreSemana = p.getDouble('cierre') ?? 0;
    }

    _calcRacha();
    setState(() {});
  }

  Future<void> _guardar() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      'ventas',
      ventas.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> _agregar(Venta v) async {
    ventas.add(v);
    await _guardar();
    _calcRacha();
    setState(() {});
  }

  Future<void> _eliminar(Venta v) async {
    ventas.remove(v);
    await _guardar();
    _calcRacha();
    setState(() {});
  }

  double _sumaDia(String seccion, [String op = '']) => ventas
      .where(
        (v) =>
            v.fecha == _hoy() &&
            v.seccion == seccion &&
            (op.isEmpty || v.operador == op),
      )
      .fold<double>(0, (s, v) => s + v.monto);

  double get _totalDia => ventas
      .where((v) => v.fecha == _hoy())
      .fold<double>(0, (s, v) => s + v.monto);

  double _totalFecha(String f) =>
      ventas.where((v) => v.fecha == f).fold<double>(0, (s, v) => s + v.monto);

  List<String> get _dias {
    final set = <String>{};
    for (final v in ventas) {
      set.add(v.fecha);
    }
    final l = set.toList()..sort((a, b) => b.compareTo(a));
    return l;
  }

  String _titulo(Venta v) {
    if (v.seccion == 'TARJETAS')
      return v.operador + (v.detalle.isEmpty ? '' : '  ' + v.detalle);
    if (v.seccion == 'BEBIDAS') return v.detalle.isEmpty ? 'Bebida' : v.detalle;
    if (v.seccion == 'PRODUCTOS')
      return v.detalle.isEmpty ? 'Producto' : v.detalle;
    return 'Llamadas';
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    body: SafeArea(
      child: tab == 0
          ? _hoyView()
          : _seccionView(
              ['TARJETAS', 'LLAMADAS', 'BEBIDAS', 'PRODUCTOS'][tab - 1],
            ),
    ),
    floatingActionButton: tab == 0
        ? null
        : FloatingActionButton(
            onPressed: () => _hoja(
              ['TARJETAS', 'LLAMADAS', 'BEBIDAS', 'PRODUCTOS'][tab - 1],
            ),
            backgroundColor: _colorSeccion(tab),
            foregroundColor: const Color(0xFF0B0F12),
            child: const Icon(Icons.add_rounded, size: 32),
          ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() => tab = i),
      backgroundColor: oscuro,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'HOY',
        ),
        NavigationDestination(
          icon: Icon(Icons.sim_card_outlined),
          selectedIcon: Icon(Icons.sim_card),
          label: 'TARJ',
        ),
        NavigationDestination(
          icon: Icon(Icons.call_outlined),
          selectedIcon: Icon(Icons.call),
          label: 'LLAM',
        ),
        NavigationDestination(
          icon: Icon(Icons.local_bar_outlined),
          selectedIcon: Icon(Icons.local_bar),
          label: 'BEB',
        ),
        NavigationDestination(
          icon: Icon(Icons.shopping_bag_outlined),
          selectedIcon: Icon(Icons.shopping_bag),
          label: 'PROD',
        ),
      ],
    ),
  );

  Widget _entrada(Widget child) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.0, end: 1.0),
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutBack,
    builder: (c, t, ch) => Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.scale(scale: 0.92 + 0.08 * t, child: ch),
    ),
    child: child,
  );

  Widget _diaHeader(String f, double total, Color c) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Row(
      children: [
        Text(
          _fechaDe(f).toUpperCase(),
          style: const TextStyle(
            color: Colors.white38,
            letterSpacing: 2,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          'Bs ' + bs(total),
          style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 14),
        ),
      ],
    ),
  );

  Widget _grupos(String? sec, Color c) {
    final ws = <Widget>[];
    for (final f in _dias) {
      final del = ventas
          .where((v) => v.fecha == f && (sec == null || v.seccion == sec))
          .toList()
          .reversed
          .toList();
      if (del.isEmpty) continue;
      final tot = del.fold<double>(0, (s, v) => s + v.monto);
      ws.add(_diaHeader(f, sec == null ? _totalFecha(f) : tot, c));
      for (final v in del) {
        ws.add(_entrada(_movCard(v)));
      }
    }
    if (ws.isEmpty) {
      ws.add(
        Container(
          padding: const EdgeInsets.symmetric(vertical: 40),
          decoration: BoxDecoration(
            color: oscuro,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Icon(
                Icons.inbox_rounded,
                color: c.withValues(alpha: 0.5),
                size: 40,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sin registros',
                style: TextStyle(color: Colors.white38),
              ),
              const Text(
                'Toca + para anotar la primera venta',
                style: TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: ws);
  }

  Widget _hoyView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [neon, tigo],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ARIES',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                        color: Color(0xFF0B0F12),
                      ),
                    ),
                    Text(
                      _fechaCorta(DateTime.now()),
                      style: TextStyle(
                        color: const Color(0xFF0B0F12).withValues(alpha: 0.65),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _pulse,
                builder: (c, ch) =>
                    Transform.scale(scale: 1 + 0.15 * _pulse.value, child: ch),
                child: const Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                racha.toString(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            color: oscuro,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: neon.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              const Text(
                'TOTAL DE HOY',
                style: TextStyle(
                  color: Colors.white38,
                  letterSpacing: 3,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (ch, a) =>
                    ScaleTransition(scale: a, child: ch),
                child: Text(
                  'Bs ' + bs(_totalDia),
                  key: ValueKey<double>(_totalDia),
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: neon,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('TIGO', tigo, _sumaDia('TARJETAS', 'TIGO')),
            _chip('VIVA', viva, _sumaDia('TARJETAS', 'VIVA')),
            _chip('ENTEL', entel, _sumaDia('TARJETAS', 'ENTEL')),
            _chip('LLAM', llamadas, _sumaDia('LLAMADAS')),
            _chip('BEB', bebidas, _sumaDia('BEBIDAS')),
            _chip('PROD', prod, _sumaDia('PRODUCTOS')),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'MOVIMIENTOS POR DIA',
          style: TextStyle(
            color: Colors.white38,
            letterSpacing: 3,
            fontSize: 12,
          ),
        ),
        _grupos(null, neon),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: oscuro,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Cierre semana pasada',
                style: TextStyle(color: Colors.white38),
              ),
              Text(
                'Bs ' + bs(cierreSemana),
                style: const TextStyle(color: oro, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(String n, Color c, double v) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: oscuro,
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: c.withValues(alpha: 0.5)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          n,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          bs(v),
          style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );

  Widget _movCard(Venta v) {
    final c = _colorDe(v);
    return GestureDetector(
      onLongPress: () => _menu(v),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: oscuro,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                v.seccion == 'TARJETAS'
                    ? Icons.sim_card_rounded
                    : (v.seccion == 'LLAMADAS'
                          ? Icons.call_rounded
                          : (v.seccion == 'BEBIDAS'
                                ? Icons.local_bar_rounded
                                : Icons.shopping_bag_rounded)),
                color: c,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titulo(v),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    (v.hora.isEmpty ? '--:--' : v.hora) +
                        '  ' +
                        v.cantidad.toString() +
                        ' x Bs ' +
                        bs(_unitDe(v)),
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              'Bs ' + bs(v.monto),
              style: TextStyle(
                color: c,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _menu(Venta v) async {
    final acc = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: oscuro,
        title: Text(_titulo(v), style: const TextStyle(color: Colors.white)),
        content: Text(
          'Bs ' +
              bs(v.monto) +
              '  ·  ' +
              (v.hora.isEmpty ? '--:--' : v.hora) +
              '  ·  ' +
              v.cantidad.toString() +
              ' x Bs ' +
              bs(_unitDe(v)),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: neon,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(c, 'editar'),
            child: const Text('Editar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: peligro),
            onPressed: () => Navigator.pop(c, 'borrar'),
            child: const Text('Eliminar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (acc == 'editar') {
      await _hoja(v.seccion, editar: v);
    } else if (acc == 'borrar') {
      await _confirmarBorrado(v);
    }
  }

  Widget _seccionView(String sec) {
    final color = _colorSeccion(
      ['TARJETAS', 'LLAMADAS', 'BEBIDAS', 'PRODUCTOS'].indexOf(sec) + 1,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(
              sec,
              style: TextStyle(
                color: color,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: oscuro,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (ch, a) =>
                  ScaleTransition(scale: a, child: ch),
              child: Text(
                'Bs ' + bs(_sumaDia(sec)),
                key: ValueKey<double>(_sumaDia(sec)),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ),
        ),
        _grupos(sec, color),
      ],
    );
  }

  InputDecoration _dec(String l) => InputDecoration(
    labelText: l,
    labelStyle: const TextStyle(color: Colors.white38),
    filled: true,
    fillColor: Colors.white10,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  Future<void> _hoja(String sec, {Venta? editar}) async {
    final color = _colorSeccion(
      ['TARJETAS', 'LLAMADAS', 'BEBIDAS', 'PRODUCTOS'].indexOf(sec) + 1,
    );
    String op = editar?.operador ?? '';
    final cant = TextEditingController(
      text: editar == null ? '1' : editar.cantidad.toString(),
    );
    final monto = TextEditingController(
      text: editar == null ? '' : bs(_unitDe(editar)),
    );
    final det = TextEditingController(text: editar?.detalle ?? '');
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: oscuro,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(c).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    editar == null ? 'NUEVO REGISTRO' : 'EDITAR REGISTRO',
                    style: TextStyle(
                      color: color,
                      letterSpacing: 3,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (sec == 'TARJETAS')
                Row(
                  children: [
                    for (final o in ['TIGO', 'VIVA', 'ENTEL'])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: op == o
                                  ? _colorOp(o)
                                  : Colors.white10,
                              foregroundColor: op == o
                                  ? const Color(0xFF0B0F12)
                                  : Colors.white70,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () => setS(() => op = o),
                            child: Text(o),
                          ),
                        ),
                      ),
                  ],
                )
              else if (sec == 'BEBIDAS' || sec == 'PRODUCTOS')
                TextField(
                  controller: det,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dec(
                    sec == 'BEBIDAS' ? 'Producto / bebida' : 'Producto',
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cant,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: _dec('Cant.'),
                      onChanged: (s) => setS(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: monto,
                      autofocus: editar == null,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: _dec('Precio c/u Bs'),
                      onChanged: (s) => setS(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      (int.tryParse(cant.text) ?? 1).toString() +
                          ' x Bs ' +
                          bs(
                            double.tryParse(monto.text.replaceAll(',', '.')) ??
                                0,
                          ),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      'Subtotal Bs ' +
                          bs(
                            (int.tryParse(cant.text) ?? 1) *
                                (double.tryParse(
                                      monto.text.replaceAll(',', '.'),
                                    ) ??
                                    0),
                          ),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: const Color(0xFF0B0F12),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: () {
                    final q = int.tryParse(cant.text) ?? 1;
                    final u =
                        double.tryParse(monto.text.replaceAll(',', '.')) ?? 0;
                    if (u <= 0) return;
                    if (sec == 'TARJETAS' && op.isEmpty) return;
                    final m = u * q;
                    KaChing.play();
                    HapticFeedback.vibrate();
                    if (editar != null) {
                      ventas.remove(editar);
                    }
                    _agregar(
                      Venta(
                        fecha: editar?.fecha ?? _hoy(),
                        hora: editar?.hora ?? _ahora(),
                        seccion: sec,
                        operador: op,
                        detalle: det.text,
                        cantidad: q,
                        monto: m,
                        unit: u,
                      ),
                    );
                    Navigator.pop(c);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          (editar == null ? 'Guardado  Bs ' : 'Editado  Bs ') +
                              bs(m),
                        ),
                        backgroundColor: color,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _confirmarBorrado(Venta v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: oscuro,
        title: const Text(
          'Eliminar registro',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Bs ' + bs(v.monto) + '  ' + v.seccion.toLowerCase(),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: peligro),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Si, eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _eliminar(v);
    }
  }
}

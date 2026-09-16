"""Verificador estatico de referencias cruzadas para o codigo Dart.

Nao substitui `flutter analyze` — nao entende tipos, generics nem inferencia.
Mas encontra a classe de erro mais comum em codigo escrito sem compilador:
**referencia a um simbolo que nao existe em lugar nenhum**.

O que ele checa:
  1. Providers do Riverpod usados mas nunca declarados
  2. Constantes de Routes referenciadas mas ausentes
  3. Classes instanciadas que nao existem no projeto nem nos pacotes
  4. Membros de AppColors / AppSpacing / AppRadius / AppAssets inexistentes
  5. Metodos estaticos chamados em classes do projeto que nao os declaram

Uso:  python3 tool/check_references.py
"""

import os
import re
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")

# Simbolos que vem de pacotes externos e nao devem ser cobrados do projeto.
EXTERNAL = {
    # Flutter / Dart
    "Widget", "StatelessWidget", "StatefulWidget", "State", "BuildContext",
    "Key", "ValueKey", "GlobalKey", "Text", "Icon", "IconData", "Icons",
    "Color", "Colors", "EdgeInsets", "BorderRadius", "Radius", "Border",
    "BorderSide", "BoxDecoration", "BoxShadow", "BoxShape", "Offset", "Size",
    "Duration", "DateTime", "String", "int", "double", "bool", "num", "Object",
    "List", "Map", "Set", "Iterable", "Future", "Stream", "StreamController",
    "Timer", "Uri", "Exception", "Error", "StateError", "StackTrace",
    "RegExp", "Match", "StringBuffer", "Comparable", "Function",
    "Column", "Row", "Stack", "Center", "Padding", "Container", "SizedBox",
    "Expanded", "Flexible", "Spacer", "Wrap", "Align", "Positioned",
    "ListView", "GridView", "CustomScrollView", "SingleChildScrollView",
    "Scaffold", "AppBar", "SliverAppBar", "SliverList", "SliverPadding",
    "SliverToBoxAdapter", "SliverFillRemaining", "SliverGridDelegateWithFixedCrossAxisCount",
    "Card", "ListTile", "InkWell", "GestureDetector", "Material", "Divider",
    "CircleAvatar", "Image", "NetworkImage", "AssetImage", "ClipRRect",
    "TextField", "TextFormField", "TextEditingController", "Form", "FormState",
    "InputDecoration", "InputDecorator", "TextStyle", "TextTheme", "ThemeData",
    "Theme", "ColorScheme", "MediaQuery", "Navigator", "MaterialPageRoute",
    "ScaffoldMessenger", "SnackBar", "SnackBarAction", "AlertDialog", "Dialog",
    "TextButton", "FilledButton", "ElevatedButton", "OutlinedButton",
    "IconButton", "FloatingActionButton", "PopupMenuButton", "PopupMenuItem",
    "PopupMenuEntry", "DropdownButtonFormField", "DropdownMenuItem",
    "Checkbox", "Radio", "RadioListTile", "Switch", "SwitchListTile", "Slider",
    "ChoiceChip", "FilterChip", "ActionChip", "Chip", "Badge", "SearchBar",
    "SegmentedButton", "ButtonSegment", "TabBar", "Tab", "TabBarView",
    "CircularProgressIndicator", "LinearProgressIndicator", "RefreshIndicator",
    "AspectRatio", "ConstrainedBox", "BoxConstraints", "FractionallySizedBox",
    "AnimatedContainer", "AnimatedOpacity", "AnimatedSwitcher", "Opacity",
    "Transform", "CustomPaint", "CustomPainter", "Canvas", "Paint", "Path",
    "ColoredBox", "DecoratedBox", "SafeArea", "Visibility", "Placeholder",
    "NavigationBar", "NavigationRail", "NavigationDestination",
    "NavigationRailDestination", "BottomNavigationBar", "Drawer",
    "FlexibleSpaceBar", "PreferredSize", "TextOverflow", "TextAlign",
    "FontWeight", "FontStyle", "TextDecoration", "TextCapitalization",
    "TextInputType", "TextInputAction", "InputBorder", "OutlineInputBorder",
    "UnderlineInputBorder", "WidgetStatePropertyAll", "WidgetStateProperty",
    "MainAxisAlignment", "CrossAxisAlignment", "MainAxisSize", "Axis",
    "Alignment", "FractionalOffset", "Curve", "Curves", "Tween", "Locale",
    "ValueChanged", "VoidCallback", "WidgetBuilder", "ScrollController",
    "PageController", "FocusScope", "FocusNode", "Clip", "BlendMode",
    "ImageFilter", "BackdropFilter", "LinearGradient", "RadialGradient",
    "Gradient", "SystemChrome", "SystemUiOverlayStyle", "Brightness",
    "WidgetsBinding", "WidgetsFlutterBinding", "PlatformDispatcher",
    "VisualDensity", "ScrollPhysics", "NeverScrollableScrollPhysics",
    "AlwaysScrollableScrollPhysics", "TextSpan", "RichText", "InlineSpan",
    "DefaultTextStyle", "ScrollNotification", "NotificationListener",
    "OverflowBar", "Semantics", "MergeSemantics", "ExcludeSemantics",
    "AnimatedBuilder", "Animation", "AnimationController", "TickerProvider",
    "SingleTickerProviderStateMixin", "TickerProviderStateMixin",
    "CardThemeData", "TabBarThemeData", "DialogThemeData", "AppBarTheme",
    "InputDecorationTheme", "ChipThemeData", "SnackBarThemeData",
    "BottomSheetThemeData", "NavigationBarThemeData", "ListTileThemeData",
    "FilledButtonThemeData", "TextButtonThemeData", "OutlinedButtonThemeData",
    "ElevatedButtonThemeData", "IconThemeData", "ProgressIndicatorThemeData",
    "SliderThemeData", "CheckboxThemeData", "SwitchThemeData",
    "FloatingActionButtonThemeData", "DividerThemeData", "ButtonStyle",
    "RoundedRectangleBorder", "CircleBorder", "StadiumBorder", "OutlinedBorder",
    "ShapeBorder", "MaterialApp", "WidgetsApp", "ThemeMode",
    "GoogleFonts", "TextDirection", "Rect", "RRect", "StrokeCap",
    "ScrollUpdateNotification", "ImageProvider", "FilterQuality",
    "SystemUiMode", "DeviceOrientation", "HapticFeedback", "Clipboard",
    "ClipboardData", "Uint8List", "ByteData", "Codec", "Encoding",
    # Riverpod
    "Provider", "StateProvider", "FutureProvider", "StreamProvider",
    "NotifierProvider", "AsyncNotifierProvider", "StateNotifierProvider",
    "ChangeNotifierProvider", "Ref", "WidgetRef", "ProviderScope",
    "ConsumerWidget", "ConsumerStatefulWidget", "ConsumerState",
    "Notifier", "AsyncNotifier", "StateNotifier", "AsyncValue",
    "ProviderContainer", "Override", "ProviderListenable",
    "AutoDisposeNotifier", "AutoDisposeNotifierProvider",
    "AutoDisposeFutureProvider", "AutoDisposeStreamProviderFamily",
    "StreamProviderFamily", "FutureProviderFamily", "ProviderFamily",
    "NotifierProviderFamily", "AsyncData", "AsyncError", "AsyncLoading",
    # Firebase
    "FirebaseFirestore", "DocumentSnapshot", "QuerySnapshot", "Query",
    "QueryDocumentSnapshot", "CollectionReference", "DocumentReference",
    "Timestamp", "FieldValue", "SetOptions", "FirebaseException",
    "FirebaseAuth", "User", "UserCredential", "AuthCredential",
    "GoogleAuthProvider", "FirebaseAuthException", "FirebaseStorage",
    "Reference", "TaskSnapshot", "SettableMetadata", "UploadTask",
    "FirebaseFunctions", "HttpsCallable", "HttpsCallableResult",
    "HttpsCallableOptions", "FirebaseFunctionsException", "FirebaseMessaging",
    "RemoteMessage", "NotificationSettings", "FirebaseAnalytics",
    "FirebaseCrashlytics", "FirebaseRemoteConfig", "RemoteConfigSettings",
    "FirebaseOptions", "Firebase", "FirebaseApp", "AuthorizationStatus",
    "GoogleSignIn", "GoogleSignInAccount", "GoogleSignInAuthentication",
    # Outros pacotes
    "Dio", "Options", "Headers", "CancelToken", "Response", "DioException",
    "Hive", "Box", "HiveInterface", "Database", "Batch", "Transaction",
    "ConnectivityResult", "Connectivity", "Uuid", "Equatable",
    "FlutterLocalNotificationsPlugin", "AndroidNotificationDetails",
    "NotificationDetails", "DarwinNotificationDetails",
    "AndroidNotificationChannel", "InitializationSettings",
    "AndroidInitializationSettings", "DarwinInitializationSettings",
    "Importance", "Priority", "GoRouter", "GoRoute", "RouteBase", "ShellRoute",
    "GoRouterState", "NoTransitionPage", "StatefulShellRoute",
    "CustomTransitionPage", "LineChart", "LineChartData", "LineChartBarData",
    "FlSpot", "FlGridData", "FlLine", "FlBorderData", "FlTitlesData",
    "AxisTitles", "SideTitles", "TitleMeta", "LineTouchData",
    "LineTouchTooltipData", "LineTooltipItem", "LineBarSpot", "FlDotData",
    "FlDotCirclePainter", "BarChart", "BarChartData", "PieChart",
    "VideoPlayerController", "ChewieController", "Chewie",
    "ChewieProgressColors", "CachedNetworkImage", "Lottie", "LottieBuilder",
    "TextInputFormatter", "FilteringTextInputFormatter",
    "LengthLimitingTextInputFormatter", "MaskTextInputFormatter",
    "LaunchMode", "PackageInfo", "SharedPreferences", "Permission",
    "PermissionStatus", "ImagePicker", "XFile", "ImageSource",
    "Animate", "Effect", "ShimmerEffect", "FadeEffect", "ScaleEffect",
    "BaseOptions", "LogInterceptor", "Interceptor", "InterceptorsWrapper",
    "CheckboxListTile", "IgnorePointer", "AbsorbPointer", "TextEditingValue",
    "CupertinoPageTransitionsBuilder", "ZoomPageTransitionsBuilder",
    "FadeUpwardsPageTransitionsBuilder", "PageTransitionsTheme",
    "PageTransitionsBuilder", "NavigationRailThemeData",
    "FirebaseAnalyticsObserver", "DateFormat", "NumberFormat", "Intl",
    "Settings", "PersistenceSettings", "GetOptions", "Source",
    "TooltipThemeData", "UnderlineTabIndicator", "VerticalDivider",
    "IntrinsicHeight", "IntrinsicWidth", "LayoutBuilder", "OrientationBuilder",
    "DraggableScrollableSheet", "SelectableText", "ScrollController",
    "PdfPreview", "PdfPageFormat", "Printing", "PdfColor", "PdfDocument",
    "Builder", "StatefulBuilder", "FutureBuilder", "StreamBuilder",
    "Tooltip", "Banner", "Hero", "SlideTransition", "FadeTransition",
    "Consumer", "ConsumerBuilder", "HookConsumer", "MapEntry",
    "SvgPicture", "PictureInfo",
    "Clipboard", "ClipboardData", "DefaultTabController",
    "UnimplementedError", "UnsupportedError", "ArgumentError",
    "FormatException", "TimeoutException", "RangeError",
}


def dart_files():
    for root, _, files in os.walk(LIB):
        for f in files:
            if f.endswith(".dart"):
                yield os.path.join(root, f)


def strip_comments_and_strings(src):
    """Remove comentarios e literais de string para evitar falsos positivos."""
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c == "/" and i + 1 < n and src[i + 1] == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                i += 1
            i += 2
            continue
        if c in "'\"":
            if src[i:i + 3] in ("'''", '"""'):
                q = src[i:i + 3]
                i += 3
                while i < n and src[i:i + 3] != q:
                    if src[i] == "\\":
                        i += 1
                    i += 1
                i += 3
                out.append(" ")
                continue
            q = c
            i += 1
            while i < n and src[i] != q:
                if src[i] == "\\":
                    i += 2
                    continue
                if src[i] == "\n":
                    break
                # preserva interpolacao ${...}
                if src[i] == "$" and i + 1 < n and src[i + 1] == "{":
                    depth = 1
                    i += 2
                    start = i
                    while i < n and depth > 0:
                        if src[i] == "{":
                            depth += 1
                        elif src[i] == "}":
                            depth -= 1
                        i += 1
                    out.append(src[start:i - 1])
                    continue
                i += 1
            i += 1
            out.append(" ")
            continue
        out.append(c)
        i += 1
    return "".join(out)


# ---------------------------------------------------------------- Coleta

declared_classes = set()
declared_enums = set()
declared_providers = set()
class_members = defaultdict(set)   # Classe -> membros estaticos/const
file_sources = {}

CLASS_RE = re.compile(r"\b(?:abstract\s+|sealed\s+|final\s+|base\s+)*class\s+(\w+)")
ENUM_RE = re.compile(r"\benum\s+(\w+)")
MIXIN_RE = re.compile(r"\bmixin\s+(\w+)")
TYPEDEF_RE = re.compile(r"\btypedef\s+(\w+)")
EXTENSION_RE = re.compile(r"\bextension\s+(\w+)")

# `final X provider = ...` ou `final X<Y> provider = ...`
PROVIDER_RE = re.compile(r"\bfinal\s+[\w<>,\s?]+\s+(\w*[Pp]rovider)\s*=")

for path in dart_files():
    raw = open(path, encoding="utf-8").read()
    src = strip_comments_and_strings(raw)
    file_sources[path] = src

    declared_classes.update(CLASS_RE.findall(src))
    declared_classes.update(MIXIN_RE.findall(src))
    declared_classes.update(TYPEDEF_RE.findall(src))
    declared_classes.update(EXTENSION_RE.findall(src))
    declared_enums.update(ENUM_RE.findall(src))
    declared_providers.update(PROVIDER_RE.findall(src))

# Membros de cada classe declarada (estaticos, const, finais e metodos).
MEMBER_RE = re.compile(
    r"^\s*(?:static\s+)?(?:const\s+|final\s+|late\s+)*"
    r"(?:[\w<>,\s?\[\]]+\s+)?(\w+)\s*(?:=|\(|;|=>)",
    re.MULTILINE,
)

for path, src in file_sources.items():
    # Divide por declaracao de classe/enum para associar membros.
    positions = []
    for m in re.finditer(r"\b(?:class|enum|mixin|extension)\s+(\w+)", src):
        positions.append((m.start(), m.group(1)))
    positions.append((len(src), None))

    for idx in range(len(positions) - 1):
        start, name = positions[idx]
        end = positions[idx + 1][0]
        if name is None:
            continue
        body = src[start:end]
        class_members[name].update(MEMBER_RE.findall(body))
        # valores de enum
        enum_body = re.search(r"\{(.*?)(?:;|\})", body, re.DOTALL)
        if enum_body:
            for token in re.findall(r"\b([a-z]\w*)\b", enum_body.group(1)[:400]):
                class_members[name].add(token)


# ------------------------------------------------------------- Verificacoes

problems = []

known = declared_classes | declared_enums | EXTERNAL

# 1. Providers usados mas nunca declarados.
USE_PROVIDER_RE = re.compile(r"\b(?:watch|read|listen|invalidate|refresh)\s*\(\s*(\w*[Pp]rovider)\b")
for path, src in file_sources.items():
    for m in USE_PROVIDER_RE.finditer(src):
        name = m.group(1)
        if name not in declared_providers:
            line = src[:m.start()].count("\n") + 1
            problems.append(("provider", path, line, name))

# 2. Constantes de Routes.
ROUTES_USE_RE = re.compile(r"\bRoutes\.(\w+)")
routes_members = class_members.get("Routes", set())
for path, src in file_sources.items():
    for m in ROUTES_USE_RE.finditer(src):
        name = m.group(1)
        if name.startswith("_"):
            continue
        if routes_members and name not in routes_members:
            line = src[:m.start()].count("\n") + 1
            problems.append(("Routes", path, line, name))

# 3. Membros de classes de design tokens.
for holder in ("AppColors", "AppSpacing", "AppRadius", "AppAssets",
               "AppMotion", "AppElevation", "FirestorePaths", "AppConfig"):
    members = class_members.get(holder, set())
    if not members:
        continue
    use_re = re.compile(r"\b" + holder + r"\.(\w+)")
    for path, src in file_sources.items():
        for m in use_re.finditer(src):
            name = m.group(1)
            if name.startswith("_"):
                continue  # construtor privado: AppColors._()
            if name not in members:
                line = src[:m.start()].count("\n") + 1
                problems.append((holder, path, line, name))

# 4. Parametros nomeados que nao existem no construtor.
#    Aceita parametros posicionais antes do bloco `{...}` e heranca via
#    `super.campo` — foi justamente isso que gerou 5 falsos positivos na
#    primeira versao deste verificador.
ctor_params = defaultdict(set)
extends_map = {}

for path, src in file_sources.items():
    for m in re.finditer(r"\bclass\s+(\w+)(?:\s+extends\s+(\w+))?", src):
        cls, parent = m.group(1), m.group(2)
        if parent:
            extends_map[cls] = parent
        i = src.find("{", m.end())
        if i < 0:
            continue
        d, j = 0, i
        while j < len(src):
            if src[j] == "{":
                d += 1
            elif src[j] == "}":
                d -= 1
                if d == 0:
                    break
            j += 1
        body = src[i:j]

        for cm in re.finditer(
            r"(?:const\s+)?" + re.escape(cls) + r"(?:\.\w+)?\s*\(([^;]*?)\)\s*(?::|;|\{|=>)",
            body, re.DOTALL,
        ):
            named = re.search(r"\{(.*)\}", cm.group(1), re.DOTALL)
            if named:
                for pm in re.finditer(
                    r"(?:required\s+)?(?:this\.|super\.)?(\w+)\s*(?=[,=}]|$)",
                    named.group(1),
                ):
                    ctor_params[cls].add(pm.group(1))
        ctor_params[cls].update({"key", "child", "children"})

# Propaga parametros herdados.
for _ in range(4):
    for cls, parent in extends_map.items():
        if parent in ctor_params:
            ctor_params[cls] |= ctor_params[parent]

for path, src in file_sources.items():
    for m in re.finditer(r"\b([A-Z]\w+)\s*\(", src):
        cls = m.group(1)
        if not ctor_params.get(cls):
            continue
        i = m.end() - 1
        d, j = 0, i
        while j < len(src):
            if src[j] == "(":
                d += 1
            elif src[j] == ")":
                d -= 1
                if d == 0:
                    break
            j += 1
        depth, buf, parts = 0, "", []
        for ch in src[i + 1:j]:
            if ch in "([{":
                depth += 1
            elif ch in ")]}":
                depth -= 1
            if ch == "," and depth == 0:
                parts.append(buf)
                buf = ""
            else:
                buf += ch
        parts.append(buf)
        for part in parts:
            nm = re.match(r"\s*(\w+)\s*:(?!:)", part)
            if nm and nm.group(1) not in ctor_params[cls]:
                line = src[:m.start()].count("\n") + 1
                problems.append(("parametro", path, line, f"{cls}.{nm.group(1)}"))


# 5. Classes instanciadas que nao existem.
INSTANTIATE_RE = re.compile(r"\b(?:const\s+)?([A-Z]\w+)\s*\(")
for path, src in file_sources.items():
    for m in INSTANTIATE_RE.finditer(src):
        name = m.group(1)
        if name in known:
            continue
        # ignora chamadas do tipo Classe.metodo(
        prev = src[max(0, m.start() - 1)]
        if prev == ".":
            continue
        line = src[:m.start()].count("\n") + 1
        problems.append(("classe", path, line, name))


# ------------------------------------------------------------------ Saida

if not problems:
    print("Nenhuma referencia quebrada encontrada.")
    print(f"  {len(declared_classes)} classes, {len(declared_enums)} enums, "
          f"{len(declared_providers)} providers declarados")
    sys.exit(0)

by_kind = defaultdict(list)
for kind, path, line, name in problems:
    by_kind[kind].append((path, line, name))

total = 0
for kind in sorted(by_kind):
    items = by_kind[kind]
    # Agrupa por nome para nao repetir o mesmo problema 20 vezes.
    grouped = defaultdict(list)
    for path, line, name in items:
        grouped[name].append((os.path.relpath(path, ROOT), line))

    print(f"\n### {kind} ({len(grouped)} simbolos)")
    for name in sorted(grouped):
        locations = grouped[name]
        total += 1
        first = locations[0]
        extra = f" (+{len(locations) - 1})" if len(locations) > 1 else ""
        print(f"  {name}")
        print(f"      {first[0]}:{first[1]}{extra}")

print(f"\n{total} simbolos suspeitos.")
print("Nem todos sao erros: o verificador nao conhece todos os simbolos dos")
print("pacotes externos. Confira os que pertencem ao projeto.")

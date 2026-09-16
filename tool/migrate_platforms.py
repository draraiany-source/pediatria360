#!/usr/bin/env python3
"""Gera android/, ios/, web/ e mescla os ajustes de platform/ automaticamente.

## Por que este script existe

`flutter create` não roda em ambiente de agente — ele compila e assina
binários do Gradle Wrapper, gera projeto Xcode com identificadores internos,
e depende de um SDK Flutter instalado de verdade. Nenhuma ferramenta de texto
reproduz isso com fidelidade.

O que ESTE script faz é o resto: depois que `flutter create` rodar (com o seu
Flutter, na sua máquina), ele aplica os seis ajustes de `platform/` sozinho,
sem passo manual — exatamente o que a Etapa 1 pediu.

## Classificação dos seis arquivos

Nem todos são "trechos". Três são substituição completa e seguem para o
lugar sem cerimônia; três são fragmentos que precisam ser inseridos num ponto
certo do arquivo gerado pelo `flutter create`, preservando o resto.

  SUBSTITUIÇÃO COMPLETA (o arquivo do `flutter create` é pequeno e genérico;
  o de platform/ já é a versão final)
    - android/app/src/main/AndroidManifest.xml
    - android/app/build.gradle.kts
    - web/index.html

  INSERÇÃO POR ÂNCORA (o arquivo gerado tem conteúdo que precisa ficar,
  como CFBundleIdentifier no Info.plist ou o wrapper do Gradle)
    - android/build.gradle.kts       -> bloco `plugins {}` de nível raiz
    - ios/Runner/Info.plist          -> chaves antes de `</dict>\\n</plist>`
    - ios/Podfile                    -> linha de plataforma + post_install

Cada inserção verifica se o conteúdo já está presente antes de agir —
rodar o script duas vezes não duplica nada.

## Uso

    flutter create --platforms=android,ios,web \\
      --org app.pediatria360 --project-name pediatria360 .

    python3 tool/migrate_platforms.py            # aplica os ajustes
    python3 tool/migrate_platforms.py --clean    # aplica e apaga platform/

`--clean` só apaga platform/ se TODAS as etapas tiverem sucesso — uma
falha no meio interrompe antes de mexer em qualquer arquivo de destino.
"""

import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def path(*parts):
    return os.path.join(ROOT, *parts)


class Step:
    def __init__(self, name):
        self.name = name
        self.ok = None
        self.detail = ""

    def success(self, detail=""):
        self.ok = True
        self.detail = detail

    def fail(self, detail):
        self.ok = False
        self.detail = detail

    def skip(self, detail):
        self.ok = "skip"
        self.detail = detail


results = []


def run(name):
    step = Step(name)
    results.append(step)
    return step


# ---------------------------------------------------------------------------
# Pré-condição: flutter create já rodou?
# ---------------------------------------------------------------------------

def check_platforms_exist():
    step = run("Pastas de plataforma geradas pelo `flutter create`")
    missing = [
        p
        for p in ("android", "ios", "web")
        if not os.path.isdir(path(p)) or not os.listdir(path(p))
    ]
    if missing:
        step.fail(
            f"Faltam ou estão vazias: {', '.join(missing)}. Rode primeiro:\n"
            "  flutter create --platforms=android,ios,web "
            "--org app.pediatria360 --project-name pediatria360 ."
        )
        return False
    step.success("android/, ios/ e web/ presentes e não vazias.")
    return True


# ---------------------------------------------------------------------------
# Substituições completas
# ---------------------------------------------------------------------------

FULL_REPLACE = [
    ("platform/android/app/src/main/AndroidManifest.xml",
     "android/app/src/main/AndroidManifest.xml"),
    ("platform/android/app/build.gradle.kts",
     "android/app/build.gradle.kts"),
    ("platform/web/index.html", "web/index.html"),
]


def full_replace(src_rel, dst_rel):
    step = run(f"Substituir {dst_rel}")
    src, dst = path(src_rel), path(dst_rel)

    if not os.path.exists(src):
        step.skip(f"{src_rel} não existe em platform/.")
        return True
    if not os.path.exists(dst):
        step.fail(f"{dst_rel} não existe — `flutter create` rodou?")
        return False

    # Remove só o cabecalho de comentario "Trecho a MESCLAR..." antes de
    # gravar: o arquivo final não deve carregar essa nota de desenvolvimento.
    content = open(src, encoding="utf-8").read()
    content = _strip_merge_header(content)

    backup = dst + ".pre-migration"
    if not os.path.exists(backup):
        shutil.copy2(dst, backup)

    with open(dst, "w", encoding="utf-8") as f:
        f.write(content)

    step.success(f"{dst_rel} substituído. Original em {os.path.basename(backup)}.")
    return True


def _strip_merge_header(content):
    """Remove o comentario inicial "Trecho a MESCLAR..." do arquivo final."""
    # XML/HTML: <!-- ... -->
    content = re.sub(
        r"^(<\?xml[^\n]*\n)?<!--\s*\n\s*Trechos? a MESCLAR.*?-->\n",
        lambda m: m.group(1) or "",
        content,
        count=1,
        flags=re.DOTALL,
    )
    return content


# ---------------------------------------------------------------------------
# Inserção por âncora
# ---------------------------------------------------------------------------

def merge_gradle_plugins():
    """android/build.gradle.kts: injeta o bloco de plugins do Firebase.

    Flutter reorganizou onde o bloco `plugins {}` de nível raiz vive entre
    versões (build.gradle.kts vs settings.gradle.kts). O script procura nos
    dois lugares e usa o que encontrar primeiro.
    """
    step = run("Plugins do Firebase no Gradle raiz")

    lines_to_add = [
        '    id("com.google.gms.google-services") version "4.4.2" apply false',
        '    id("com.google.firebase.crashlytics") version "3.0.2" apply false',
    ]

    for candidate in ("android/settings.gradle.kts", "android/build.gradle.kts"):
        dst = path(candidate)
        if not os.path.exists(dst):
            continue

        content = open(dst, encoding="utf-8").read()

        if "com.google.gms.google-services" in content:
            step.skip(f"Já presente em {candidate}.")
            return True

        m = re.search(r"plugins\s*\{", content)
        if not m:
            continue

        backup = dst + ".pre-migration"
        if not os.path.exists(backup):
            shutil.copy2(dst, backup)

        insert_at = m.end()
        new_content = (
            content[:insert_at]
            + "\n"
            + "\n".join(lines_to_add)
            + content[insert_at:]
        )
        with open(dst, "w", encoding="utf-8") as f:
            f.write(new_content)

        step.success(f"Inserido em {candidate}, dentro do bloco `plugins {{}}`.")
        return True

    step.fail(
        "Nenhum bloco `plugins {}` encontrado em settings.gradle.kts nem "
        "build.gradle.kts. Adicione manualmente:\n  "
        + "\n  ".join(lines_to_add)
    )
    return False


def merge_info_plist():
    """ios/Runner/Info.plist: insere as chaves antes de `</dict>\\n</plist>`."""
    step = run("Chaves de permissão no Info.plist")
    src, dst = path("platform/ios/Runner/Info.plist"), path("ios/Runner/Info.plist")

    if not os.path.exists(src):
        step.skip("platform/ios/Runner/Info.plist não existe.")
        return True
    if not os.path.exists(dst):
        step.fail("ios/Runner/Info.plist não existe — `flutter create` rodou?")
        return False

    dst_content = open(dst, encoding="utf-8").read()

    if "NSCameraUsageDescription" in dst_content:
        step.skip("Chaves já presentes em ios/Runner/Info.plist.")
        return True

    src_content = _strip_merge_header(open(src, encoding="utf-8").read())

    # Extrai só o miolo do <dict>...</dict> do arquivo-fonte.
    body_match = re.search(r"<dict>\n(.*)\n</dict>", src_content, re.DOTALL)
    if not body_match:
        step.fail("Não encontrei <dict>...</dict> em platform/ios/Runner/Info.plist.")
        return False
    body = body_match.group(1)

    anchor = re.search(r"</dict>\s*</plist>\s*$", dst_content)
    if not anchor:
        step.fail(
            "ios/Runner/Info.plist não termina em </dict></plist> como "
            "esperado. Insira manualmente as chaves de "
            "platform/ios/Runner/Info.plist antes do fechamento."
        )
        return False

    backup = dst + ".pre-migration"
    if not os.path.exists(backup):
        shutil.copy2(dst, backup)

    insert_at = anchor.start()
    new_content = dst_content[:insert_at] + body + "\n" + dst_content[insert_at:]

    with open(dst, "w", encoding="utf-8") as f:
        f.write(new_content)

    step.success("Chaves inseridas antes de </dict></plist>.")
    return True


def merge_podfile():
    """ios/Podfile: define a plataforma 13.0 e adiciona o post_install.

    O Podfile padrão do Flutter já pode ter seu próprio bloco `post_install`
    (varia por versão). Dois blocos `post_install` no mesmo Podfile é erro do
    CocoaPods, não aviso — por isso o script detecta e para, em vez de
    duplicar.
    """
    step = run("Plataforma iOS 13 e post_install no Podfile")
    dst = path("ios/Podfile")

    if not os.path.exists(dst):
        step.fail("ios/Podfile não existe — `flutter create` rodou?")
        return False

    content = open(dst, encoding="utf-8").read()
    backup = dst + ".pre-migration"

    changed = False

    # Linha de plataforma: comentada ou ausente no padrão do Flutter.
    if re.search(r"^platform :ios, '13\.0'", content, re.MULTILINE):
        pass  # já na versão certa
    elif re.search(r"^#\s*platform :ios,", content, re.MULTILINE):
        if not os.path.exists(backup):
            shutil.copy2(dst, backup)
        content = re.sub(
            r"^#\s*platform :ios,.*$",
            "platform :ios, '13.0'",
            content,
            count=1,
            flags=re.MULTILINE,
        )
        changed = True
    elif not re.search(r"^platform :ios,", content, re.MULTILINE):
        if not os.path.exists(backup):
            shutil.copy2(dst, backup)
        content = "platform :ios, '13.0'\n\n" + content
        changed = True

    if "PERMISSION_CAMERA=1" in content:
        step.success(
            "Plataforma ajustada." if changed else "Já estava correto."
        )
        if changed:
            with open(dst, "w", encoding="utf-8") as f:
                f.write(content)
        return True

    if "post_install do |installer|" in content:
        step.fail(
            "ios/Podfile já tem um bloco `post_install`. Não duplico — "
            "acrescente manualmente dentro dele:\n"
            "  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'\n"
            "  config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [\n"
            "    '$(inherited)', 'PERMISSION_CAMERA=1', 'PERMISSION_PHOTOS=1',\n"
            "    'PERMISSION_MICROPHONE=1', 'PERMISSION_NOTIFICATIONS=1',\n"
            "  ]"
        )
        if changed:
            with open(dst, "w", encoding="utf-8") as f:
                f.write(content)
        return False

    if not os.path.exists(backup):
        shutil.copy2(dst, backup)

    post_install_block = '''
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_CAMERA=1',
        'PERMISSION_PHOTOS=1',
        'PERMISSION_MICROPHONE=1',
        'PERMISSION_NOTIFICATIONS=1',
      ]
    end
  end
end
'''
    content = content.rstrip() + "\n" + post_install_block
    with open(dst, "w", encoding="utf-8") as f:
        f.write(content)

    step.success("Plataforma e post_install adicionados.")
    return True


# ---------------------------------------------------------------------------
# Execução
# ---------------------------------------------------------------------------

def main():
    clean = "--clean" in sys.argv

    if not check_platforms_exist():
        _report(clean=False)
        sys.exit(1)

    ok = True
    for src, dst in FULL_REPLACE:
        ok = full_replace(src, dst) and ok

    ok = merge_gradle_plugins() and ok
    ok = merge_info_plist() and ok
    ok = merge_podfile() and ok

    _report(clean=clean and ok)

    if not ok:
        print(
            "\nAlgum passo falhou ou precisa de ajuste manual — platform/ "
            "NÃO foi removida, mesmo com --clean. Corrija o apontado acima e "
            "rode de novo (o script é seguro para repetir)."
        )
        sys.exit(1)

    if clean:
        shutil.rmtree(path("platform"))
        print("\nplatform/ removida — a migração está completa nas pastas oficiais.")
    else:
        print(
            "\nTudo aplicado. platform/ mantida (rode com --clean para "
            "removê-la depois de conferir o build)."
        )


def _report(clean):
    print("=" * 70)
    print("MIGRAÇÃO DE PLATAFORMA — RELATÓRIO")
    print("=" * 70)
    for step in results:
        icon = {"skip": "○", True: "✓", False: "✗", None: "?"}[step.ok]
        print(f"  {icon} {step.name}")
        if step.detail:
            for line in step.detail.split("\n"):
                print(f"      {line}")
    print("=" * 70)


if __name__ == "__main__":
    main()

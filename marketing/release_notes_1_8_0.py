#!/usr/bin/env python3
"""Write 1.8.0 release notes into fastlane/metadata/<locale>/release_notes.txt.

Reflects the actual 1.8.0 *binary* changes (paywall clarity, first-run welcome, more in-app
localization, fixes) — NOT the store-side asset work (iPad screenshots/video/CPPs).
English is written to every locale; the top revenue markets get localized notes.
Run: python3 marketing/release_notes_1_8_0.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
META = ROOT / "fastlane" / "metadata"

EN = (
    "What's new in 1.8.0\n"
    "• A clearer way to unlock NumPad Pro — see every pack and premium theme you get, "
    "one time, with no subscription.\n"
    "• A quick welcome so you don't miss Pro features like tax & tip and clipboard history.\n"
    "• More of the app is translated into your language.\n"
    "• Performance improvements and bug fixes."
)

LOCALIZED = {
    "de-DE": (
        "Neu in 1.8.0\n"
        "• NumPad Pro einfacher freischalten – sieh alle Packs und Premium-Designs, "
        "einmalig, ohne Abo.\n"
        "• Eine kurze Einführung, damit du Pro-Funktionen wie Steuer & Trinkgeld und "
        "den Zwischenablageverlauf nicht verpasst.\n"
        "• Mehr von der App ist jetzt in deiner Sprache.\n"
        "• Leistungsverbesserungen und Fehlerbehebungen."
    ),
    "fr-FR": (
        "Nouveautés de la version 1.8.0\n"
        "• Débloquez NumPad Pro plus facilement : tous les packs et thèmes premium, "
        "en un seul achat, sans abonnement.\n"
        "• Une présentation rapide pour ne rien manquer des fonctions Pro comme la taxe "
        "et le pourboire et l'historique du presse-papiers.\n"
        "• L'application est davantage traduite dans votre langue.\n"
        "• Améliorations des performances et corrections de bugs."
    ),
    "fr-CA": (
        "Nouveautés de la version 1.8.0\n"
        "• Débloquez NumPad Pro plus facilement : tous les packs et thèmes premium, "
        "en un seul achat, sans abonnement.\n"
        "• Une présentation rapide pour ne rien manquer des fonctions Pro.\n"
        "• L'application est davantage traduite dans votre langue.\n"
        "• Améliorations des performances et corrections de bugs."
    ),
    "es-ES": (
        "Novedades de la versión 1.8.0\n"
        "• Desbloquea NumPad Pro más fácilmente: todos los paquetes y temas premium, "
        "un solo pago, sin suscripción.\n"
        "• Una breve bienvenida para que no te pierdas funciones Pro como impuesto y "
        "propina y el historial del portapapeles.\n"
        "• Más partes de la app están traducidas a tu idioma.\n"
        "• Mejoras de rendimiento y corrección de errores."
    ),
    "es-MX": (
        "Novedades de la versión 1.8.0\n"
        "• Desbloquea NumPad Pro más fácil: todos los paquetes y temas premium, "
        "un solo pago, sin suscripción.\n"
        "• Una breve bienvenida para que no te pierdas funciones Pro como impuesto y "
        "propina e historial del portapapeles.\n"
        "• Más de la app está traducida a tu idioma.\n"
        "• Mejoras de rendimiento y corrección de errores."
    ),
    "pt-BR": (
        "Novidades da versão 1.8.0\n"
        "• Desbloqueie o NumPad Pro com mais facilidade: todos os pacotes e temas premium, "
        "uma única compra, sem assinatura.\n"
        "• Uma rápida introdução para você não perder recursos Pro como imposto e gorjeta "
        "e o histórico da área de transferência.\n"
        "• Mais partes do app traduzidas para o seu idioma.\n"
        "• Melhorias de desempenho e correções de bugs."
    ),
    "pt-PT": (
        "Novidades da versão 1.8.0\n"
        "• Desbloqueie o NumPad Pro com mais facilidade: todos os pacotes e temas premium, "
        "uma única compra, sem subscrição.\n"
        "• Uma breve introdução para não perder funcionalidades Pro como imposto e gorjeta "
        "e o histórico da área de transferência.\n"
        "• Mais partes da app traduzidas para o seu idioma.\n"
        "• Melhorias de desempenho e correção de erros."
    ),
    "it": (
        "Novità della versione 1.8.0\n"
        "• Sblocca NumPad Pro più facilmente: tutti i pacchetti e i temi premium, "
        "un solo acquisto, senza abbonamento.\n"
        "• Una rapida introduzione per non perdere le funzioni Pro come tasse e mancia "
        "e la cronologia degli appunti.\n"
        "• Più parti dell'app tradotte nella tua lingua.\n"
        "• Miglioramenti delle prestazioni e correzioni di bug."
    ),
    "nl-NL": (
        "Nieuw in 1.8.0\n"
        "• Ontgrendel NumPad Pro eenvoudiger: alle packs en premiumthema's, "
        "eenmalig, zonder abonnement.\n"
        "• Een korte introductie zodat je Pro-functies zoals btw & fooi en "
        "klembordgeschiedenis niet mist.\n"
        "• Meer van de app is vertaald in jouw taal.\n"
        "• Prestatieverbeteringen en bugfixes."
    ),
    "ja": (
        "バージョン1.8.0の新機能\n"
        "• NumPad Proをもっと簡単にアンロック。すべてのパックとプレミアムテーマを、"
        "サブスクリプションなしの一度の購入で。\n"
        "• 税＆チップやクリップボード履歴などのPro機能を見逃さないための簡単なご案内。\n"
        "• アプリの対応言語がさらに充実しました。\n"
        "• パフォーマンスの向上とバグ修正。"
    ),
    "ko": (
        "버전 1.8.0의 새로운 기능\n"
        "• NumPad Pro를 더 쉽게 잠금 해제하세요. 모든 팩과 프리미엄 테마를 "
        "구독 없이 한 번의 구매로.\n"
        "• 세금＆팁, 클립보드 기록 같은 Pro 기능을 놓치지 않도록 간단한 안내를 추가했습니다.\n"
        "• 더 많은 화면이 사용 중인 언어로 번역되었습니다.\n"
        "• 성능 개선 및 버그 수정."
    ),
    "zh-Hans": (
        "1.8.0 版新功能\n"
        "• 更轻松解锁 NumPad Pro：所有键盘包和高级主题，一次购买，无需订阅。\n"
        "• 新增简短引导，让你不错过税费与小费、剪贴板历史等 Pro 功能。\n"
        "• 应用更多界面已支持你的语言。\n"
        "• 性能优化与问题修复。"
    ),
    "zh-Hant": (
        "1.8.0 版新功能\n"
        "• 更輕鬆解鎖 NumPad Pro：所有鍵盤包與進階主題，一次購買，無需訂閱。\n"
        "• 新增簡短導覽，讓你不錯過稅費與小費、剪貼簿記錄等 Pro 功能。\n"
        "• 應用程式更多介面已支援你的語言。\n"
        "• 效能優化與問題修正。"
    ),
    "ru": (
        "Что нового в версии 1.8.0\n"
        "• Проще разблокировать NumPad Pro: все паки и премиум-темы, "
        "разовая покупка, без подписки.\n"
        "• Краткое знакомство, чтобы вы не пропустили функции Pro — налог и чаевые "
        "и историю буфера обмена.\n"
        "• Больше разделов приложения переведено на ваш язык.\n"
        "• Улучшения производительности и исправления ошибок."
    ),
}


def main():
    written, localized = 0, 0
    longest = 0
    for d in sorted(p for p in META.iterdir() if p.is_dir()):
        notes = LOCALIZED.get(d.name, EN)
        if d.name in LOCALIZED:
            localized += 1
        (d / "release_notes.txt").write_text(notes + "\n", encoding="utf-8")
        longest = max(longest, len(notes))
        written += 1
    print(f"wrote release_notes.txt to {written} locales ({localized} localized, rest English)")
    print(f"longest note: {longest} chars (limit 4000)")


if __name__ == "__main__":
    main()

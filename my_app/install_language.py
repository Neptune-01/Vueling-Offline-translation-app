import argostranslate.package
import argostranslate.translate
import argostranslate.installation

# Liste des langues à installer
languages = [
    ("en", "fr"),  # Anglais → Français
    ("fr", "en"),  # Français → Anglais
    ("en", "es"),  # Anglais → Espagnol
    ("es", "en"),  # Espagnol → Anglais
    ("en", "de"),  # Anglais → Allemand
    ("de", "en"),  # Allemand → Anglais
    ("en", "it"),  # Anglais → Italien
    ("it", "en"),  # Italien → Anglais
]

for src, tgt in languages:
    print(f"📥 Téléchargement du modèle {src} → {tgt}...")
    
    available_packages = argostranslate.package.get_available_packages()
    package_to_install = next(
        (pkg for pkg in available_packages if pkg.from_code == src and pkg.to_code == tgt),
        None
    )

    if package_to_install:
        downloaded_package_path = package_to_install.download()
        argostranslate.package.install_from_path(downloaded_package_path)
        print(f"✅ Modèle {src} → {tgt} installé avec succès !")
    else:
        print(f"⚠️ Aucun modèle trouvé pour {src} → {tgt}.")

print("🚀 Installation des langues terminée !")

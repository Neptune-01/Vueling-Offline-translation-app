// translation.js
class TranslationManager {
    constructor() {
        this.cache = new Map();
        this.currentLanguage = 'french';
    }

    async processText(text) {
        // Si le texte est vide
        if (!text.trim()) return '';

        try {
            // On traduit toujours tout le texte en cours
            const translation = await this.translate(text);
            return translation;
        } catch (error) {
            console.error("Erreur de traduction:", error);
            return text;
        }
    }

    async translate(text) {
        try {
            const response = await fetch('http://localhost:8000/api/v1/translate', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    text: text,
                    target_language: this.currentLanguage
                })
            });
            const result = await response.json();
            return result.translation;
        } catch (error) {
            console.error("Erreur de traduction:", error);
            return text;
        }
    }

    setLanguage(language) {
        this.currentLanguage = language;
        this.cache.clear();
    }
}

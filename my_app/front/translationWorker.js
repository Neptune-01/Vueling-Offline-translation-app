self.onmessage = async function(e) {
    const { sentence, targetLanguage } = e.data;
    
    try {
        const response = await fetch('http://localhost:8000/api/v1/translate', {
            method: 'POST',
            headers: { 
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                text: sentence,
                target_language: targetLanguage
            })
        });

        const result = await response.json();
        self.postMessage({
            translation: result.translation
        });
    } catch (error) {
        self.postMessage({
            error: error.message
        });
    }
};
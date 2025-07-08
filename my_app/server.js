const express = require('express');
const cors = require('cors');
const axios = require('axios');
const app = express();

app.use(cors());
app.use(express.json());

let broadcastMessages = [];
let conversationMessages = [];

// Endpoint pour récupérer les messages
app.get('/messages/:type', (req, res) => {
  const { type } = req.params;
  res.json(type === 'conversation' ? conversationMessages : broadcastMessages);
});

// Endpoint pour envoyer des messages
app.post('/messages/:type', (req, res) => {
  const { type } = req.params;
  const { message, language } = req.body;
  const newMessage = { message, language, timestamp: new Date() };

  if (type === 'conversation') {
    conversationMessages.push(newMessage);
  } else {
    broadcastMessages.push(newMessage);
  }

  res.json({ success: true });
});

// Nouvel endpoint pour la traduction
app.post('/translate', async (req, res) => {
  const { text, target_language, source_language } = req.body;

  try {
    // Envoyer une requête à l'API Python
    const response = await axios.post('http://localhost:8000/api/v1/translate', {
      text,
      target_language,
      source_language,
    });

    // Renvoyer la réponse de l'API Python au client
    res.json(response.data);
  } catch (error) {
    console.error('Error calling translation API:', error);
    res.status(500).json({ error: 'Failed to translate text' });
  }
});

app.listen(3000, () => {
  console.log('Server running on port 3000');
});
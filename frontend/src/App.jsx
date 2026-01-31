import React, { useState, useEffect, useRef } from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';

// Use relative URL to go through webpack proxy (dev) or nginx proxy (prod)
const API_URL = process.env.REACT_APP_API_URL || '';

function App() {
    const [apiMessage, setApiMessage] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    // Chat state
    const [chatHistory, setChatHistory] = useState([]);
    const [inputMessage, setInputMessage] = useState('');
    const [chatLoading, setChatLoading] = useState(false);
    const [chatError, setChatError] = useState(null);
    const chatEndRef = useRef(null);

    // Initial API health check
    useEffect(() => {
        fetch(`${API_URL}/api/hello`)
            .then(response => {
                if (!response.ok) throw new Error('API request failed');
                return response.json();
            })
            .then(data => {
                setApiMessage(data);
                setLoading(false);
            })
            .catch(err => {
                setError(err.message);
                setLoading(false);
            });
    }, []);

    // Auto-scroll to bottom of chat
    useEffect(() => {
        chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    }, [chatHistory]);

    const sendMessage = async (message) => {
        if (!message.trim()) return;

        setChatLoading(true);
        setChatError(null);

        // Add user message to UI immediately
        const newUserMessage = { role: 'user', content: message };
        setChatHistory(prev => [...prev, newUserMessage]);
        setInputMessage('');

        try {
            const response = await fetch(`${API_URL}/api/chat`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    message: message,
                    history: chatHistory
                })
            });

            if (!response.ok) {
                throw new Error('Chat request failed');
            }

            const data = await response.json();

            // Add assistant response
            setChatHistory(prev => [...prev, { role: 'assistant', content: data.response }]);
        } catch (err) {
            setChatError(err.message);
            // Remove the user message if request failed
            setChatHistory(prev => prev.slice(0, -1));
        } finally {
            setChatLoading(false);
        }
    };

    const handleSubmit = (e) => {
        e.preventDefault();
        sendMessage(inputMessage);
    };

    const handleQuickQuestion = () => {
        sendMessage("What's the marginal fuel right now?");
    };

    return (
        <div className="container">
            <div className="card">
                <h1 className="title">Power Grid LLM</h1>
                <p className="subtitle">Carbon-aware scheduling for your home</p>

                <div className="status-box">
                    {loading && <p className="loading">Connecting to backend...</p>}
                    {error && <p className="error">Error: {error}</p>}
                    {apiMessage && (
                        <p className="message connected-indicator">Connected</p>
                    )}
                </div>

                {/* Chat Section */}
                <div className="chat-section">
                    <h3 className="info-title">Ask About the Grid</h3>

                    {/* Show quick question button only before conversation starts */}
                    {chatHistory.length === 0 && !chatLoading && (
                        <button
                            className="quick-question-btn"
                            onClick={handleQuickQuestion}
                            disabled={chatLoading}
                        >
                            What's the marginal fuel right now?
                        </button>
                    )}

                    {/* Show loading indicator when waiting for first response */}
                    {chatHistory.length === 0 && chatLoading && (
                        <div className="initial-loading">
                            <p className="typing-indicator">
                                <span></span><span></span><span></span>
                            </p>
                            <p className="loading-text">Checking the grid...</p>
                        </div>
                    )}

                    {/* Chat History - only show after conversation starts */}
                    {chatHistory.length > 0 && (
                        <>
                            <div className="chat-history">
                                {chatHistory.map((msg, index) => (
                                    <div
                                        key={index}
                                        className={`chat-message ${msg.role}`}
                                    >
                                        <span className="message-role">
                                            {msg.role === 'user' ? 'You' : 'Assistant'}
                                        </span>
                                        <p className="message-content">{msg.content}</p>
                                    </div>
                                ))}
                                {chatLoading && (
                                    <div className="chat-message assistant loading">
                                        <span className="message-role">Assistant</span>
                                        <p className="message-content typing-indicator">
                                            <span></span><span></span><span></span>
                                        </p>
                                    </div>
                                )}
                                <div ref={chatEndRef} />
                            </div>

                            {chatError && (
                                <p className="error chat-error">Error: {chatError}</p>
                            )}

                            {/* Follow-up Input Form */}
                            <form onSubmit={handleSubmit} className="chat-input-form">
                                <input
                                    type="text"
                                    value={inputMessage}
                                    onChange={(e) => setInputMessage(e.target.value)}
                                    placeholder="Ask a follow-up question..."
                                    disabled={chatLoading}
                                    className="chat-input"
                                />
                                <button
                                    type="submit"
                                    disabled={chatLoading || !inputMessage.trim()}
                                    className="send-btn"
                                >
                                    Send
                                </button>
                            </form>
                        </>
                    )}
                </div>
            </div>
        </div>
    );
}

// Render the app
const container = document.getElementById('root');
const root = createRoot(container);
root.render(<App />);

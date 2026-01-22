import React, { useState, useEffect } from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';

// Use relative URL to go through webpack proxy (dev) or nginx proxy (prod)
const API_URL = process.env.REACT_APP_API_URL || '';

function App() {
    const [apiMessage, setApiMessage] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

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

    return (
        <div className="container">
            <div className="card">
                <h1 className="title">Power Grid LLM</h1>
                <p className="subtitle">Carbon-aware scheduling for your home</p>

                <div className="status-box">
                    {loading && <p className="loading">Connecting to backend...</p>}
                    {error && <p className="error">Error: {error}</p>}
                    {apiMessage && (
                        <>
                            <p className="message">{apiMessage.message}</p>
                            <p className="hint">{apiMessage.hint}</p>
                        </>
                    )}
                </div>

                <div className="info-box">
                    <h3 className="info-title">Coming Soon</h3>
                    <ul className="feature-list">
                        <li>Real-time power grid mix visualization</li>
                        <li>Optimal laundry timing recommendations</li>
                        <li>Carbon footprint tracking</li>
                    </ul>
                </div>
            </div>
        </div>
    );
}

// Render the app
const container = document.getElementById('root');
const root = createRoot(container);
root.render(<App />);

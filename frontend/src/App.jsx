import React, { useState, useEffect } from 'react';
import { createRoot } from 'react-dom/client';

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
        <div style={styles.container}>
            <div style={styles.card}>
                <h1 style={styles.title}>Power Grid LLM</h1>
                <p style={styles.subtitle}>Carbon-aware scheduling for your home</p>

                <div style={styles.statusBox}>
                    {loading && <p style={styles.loading}>Connecting to backend...</p>}
                    {error && <p style={styles.error}>Error: {error}</p>}
                    {apiMessage && (
                        <>
                            <p style={styles.message}>{apiMessage.message}</p>
                            <p style={styles.hint}>{apiMessage.hint}</p>
                        </>
                    )}
                </div>

                <div style={styles.infoBox}>
                    <h3 style={styles.infoTitle}>Coming Soon</h3>
                    <ul style={styles.featureList}>
                        <li>Real-time power grid mix visualization</li>
                        <li>Optimal laundry timing recommendations</li>
                        <li>Carbon footprint tracking</li>
                    </ul>
                </div>
            </div>
        </div>
    );
}

const styles = {
    container: {
        padding: '20px',
        textAlign: 'center',
    },
    card: {
        background: 'rgba(255, 255, 255, 0.05)',
        borderRadius: '16px',
        padding: '40px',
        maxWidth: '500px',
        backdropFilter: 'blur(10px)',
        border: '1px solid rgba(255, 255, 255, 0.1)',
    },
    title: {
        fontSize: '2.5rem',
        marginBottom: '10px',
        background: 'linear-gradient(135deg, #4ade80, #22d3ee)',
        WebkitBackgroundClip: 'text',
        WebkitTextFillColor: 'transparent',
    },
    subtitle: {
        fontSize: '1.1rem',
        color: '#a0a0a0',
        marginBottom: '30px',
    },
    statusBox: {
        background: 'rgba(0, 0, 0, 0.2)',
        borderRadius: '8px',
        padding: '20px',
        marginBottom: '20px',
    },
    loading: {
        color: '#22d3ee',
    },
    error: {
        color: '#ef4444',
    },
    message: {
        fontSize: '1.2rem',
        color: '#4ade80',
        marginBottom: '10px',
    },
    hint: {
        color: '#a0a0a0',
        fontStyle: 'italic',
    },
    infoBox: {
        textAlign: 'left',
        marginTop: '20px',
    },
    infoTitle: {
        fontSize: '1rem',
        color: '#22d3ee',
        marginBottom: '10px',
    },
    featureList: {
        listStyle: 'none',
        padding: 0,
    },
};

// Add list item styles via CSS-in-JS
const listItemStyle = {
    padding: '8px 0',
    borderBottom: '1px solid rgba(255, 255, 255, 0.05)',
    paddingLeft: '20px',
    position: 'relative',
};

// Render the app
const container = document.getElementById('root');
const root = createRoot(container);
root.render(<App />);

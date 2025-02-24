# File: static/app.js
const { useState, useEffect } = React;

function BitcoinExplorer() {
    const [dbInfo, setDbInfo] = useState(null);
    const [question, setQuestion] = useState('');
    const [sql, setSql] = useState('');
    const [results, setResults] = useState(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);

    useEffect(() => {
        fetchDbInfo();
    }, []);

    const fetchDbInfo = async () => {
        try {
            const response = await fetch('/api/db-info');
            const data = await response.json();
            setDbInfo(data);
        } catch (err) {
            setError('Failed to fetch database info');
        }
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        setLoading(true);
        setError(null);
        
        try {
            const response = await fetch('/api/query', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ question }),
            });
            
            const data = await response.json();
            setSql(data.sql);
            setResults(data.results);
        } catch (err) {
            setError('Failed to process query');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="app-container">
            <div className="content-container">
                <h1 className="text-4xl font-bold text-center text-gray-800 mb-8">
                    Bitcoin Blockchain Explorer
                </h1>

                {/* Database Info Card */}
                <div className="card">
                    <h2 className="card-title">Database Information</h2>
                    {dbInfo ? (
                        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                            <div className="bg-blue-50 p-4 rounded-lg">
                                <div className="text-sm text-gray-600">Total Blocks</div>
                                <div className="text-2xl font-bold text-blue-600">{dbInfo.total_blocks}</div>
                            </div>
                            <div className="bg-green-50 p-4 rounded-lg">
                                <div className="text-sm text-gray-600">Height Range</div>
                                <div className="text-2xl font-bold text-green-600">
                                    {dbInfo.min_height} - {dbInfo.max_height}
                                </div>
                            </div>
                            <div className="bg-purple-50 p-4 rounded-lg">
                                <div className="text-sm text-gray-600">Total Tables</div>
                                <div className="text-2xl font-bold text-purple-600">{dbInfo.total_tables}</div>
                            </div>
                        </div>
                    ) : (
                        <div>Loading database information...</div>
                    )}
                </div>

                {/* Query Input Card */}
                <div className="card">
                    <h2 className="card-title">Ask Questions</h2>
                    <form onSubmit={handleSubmit}>
                        <textarea
                            className="input-field"
                            value={question}
                            onChange={(e) => setQuestion(e.target.value)}
                            placeholder="Ask a question about the Bitcoin blockchain (e.g., 'What is the average block size in the last 100 blocks?')"
                            rows="4"
                        />
                        <button
                            type="submit"
                            disabled={loading}
                            className="button"
                        >
                            {loading ? 'Processing...' : 'Submit Question'}
                        </button>
                    </form>
                </div>

                {/* SQL Query Card */}
                {sql && (
                    <div className="card">
                        <h2 className="card-title">Generated SQL Query</h2>
                        <pre className="bg-gray-100 p-4 rounded-lg overflow-x-auto">
                            {sql}
                        </pre>
                    </div>
                )}

                {/* Results Card */}
                {results && (
                    <div className="card">
                        <h2 className="card-title">Query Results</h2>
                        <div className="table-container">
                            <table className="table">
                                <thead>
                                    <tr>
                                        {Object.keys(results[0] || {}).map((key) => (
                                            <th key={key}>{key}</th>
                                        ))}
                                    </tr>
                                </thead>
                                <tbody>
                                    {results.map((row, i) => (
                                        <tr key={i}>
                                            {Object.values(row).map((value, j) => (
                                                <td key={j}>
                                                    {typeof value === 'object' ? JSON.stringify(value) : value}
                                                </td>
                                            ))}
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    </div>
                )}

                {/* Error Display */}
                {error && (
                    <div className="error">
                        {error}
                    </div>
                )}
            </div>
        </div>
    );
}

ReactDOM.render(<BitcoinExplorer />, document.getElementById('root'));
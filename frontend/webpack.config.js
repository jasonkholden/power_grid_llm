const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const webpack = require('webpack');

module.exports = (env, argv) => {
    const isProduction = argv.mode === 'production';

    return {
        entry: './src/App.jsx',
        output: {
            path: path.resolve(__dirname, 'dist'),
            filename: isProduction ? '[name].[contenthash].js' : '[name].js',
            clean: true,
            publicPath: '/',
        },
        module: {
            rules: [
                {
                    test: /\.(js|jsx)$/,
                    exclude: /node_modules/,
                    use: {
                        loader: 'babel-loader',
                        options: {
                            presets: ['@babel/preset-env', '@babel/preset-react'],
                        },
                    },
                },
                {
                    test: /\.css$/,
                    use: ['style-loader', 'css-loader'],
                },
            ],
        },
        resolve: {
            extensions: ['.js', '.jsx'],
        },
        plugins: [
            new HtmlWebpackPlugin({
                template: './src/index.html',
                filename: 'index.html',
            }),
            new webpack.DefinePlugin({
                'process.env.REACT_APP_API_URL': JSON.stringify(
                    process.env.REACT_APP_API_URL || (isProduction ? '' : 'http://localhost:8001')
                ),
            }),
        ],
        devServer: {
            static: {
                directory: path.join(__dirname, 'dist'),
            },
            port: 3001,
            hot: true,
            historyApiFallback: true,
            client: {
                webSocketURL: 'ws://localhost:3001/ws',
            },
            proxy: [
                {
                    context: ['/api'],
                    target: process.env.BACKEND_URL || 'http://backend:8001',
                    changeOrigin: true,
                },
            ],
        },
        optimization: {
            splitChunks: {
                chunks: 'all',
            },
        },
    };
};

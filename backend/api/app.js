require('dotenv').config()

const express = require('express')
const cors = require('cors')

const itemsRouter = require('./routes/items')
const indexesRouter = require('./routes/indexes')
const authRouter = require('./routes/auth')

const app = express()

app.use(cors())
app.use(express.json())

app.get('/', (req, res) => {
  res.json({ status: 'ok', message: 'HypeTerminal API running' })
})

app.use('/items', itemsRouter)
app.use('/indexes', indexesRouter)
app.use('/auth', authRouter)

// 404 handler — catches any route not matched above
app.use((req, res) => {
  res.status(404).json({ error: `Route ${req.method} ${req.path} not found` })
})

// Global error handler — catches anything thrown without a try/catch
app.use((err, req, res, next) => {
  console.error(err)
  res.status(500).json({ error: 'Internal server error' })
})

const PORT = process.env.PORT || 3000
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`)
})
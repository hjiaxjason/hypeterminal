const express = require('express')
const router = express.Router()
const pool = require('../config/db')

// GET /indexes - all indexes (Nike index, )
router.get('/', async (req, res) => {
    try {
        const { rows } = await pool.query(
            'SELECT * FROM indexes'
        )
        res.json(rows)
    } catch(err) {
        console.error(err)
        res.status(500).json({ error: 'Server error'})
    }
})

// GET /indexes/:id - single index detail + its components
router.get('/:id', async (req, res) => {
    try {
        const { id } = req.params
        const { rows } = await pool.query(
            'SELECT * FROM indexes WHERE id = $1',
            [id]
        )
        if (rows.length == 0) return res.status(404).json({ error: 'Not found' })
        res.json(rows[0])
    } catch(err) {
        console.error(err)
        res.status(500).json({ error: 'Server error' })
    }
})

// GET /indexes/:id/history - index value over time
router.get('/:id/history', async (req, res) => {
    try {
        const { id } = req.params
        const { rows } = await pool.query(
            `SELECT * FROM index_history
            WHERE index_id = $1
            ORDER BY recorded_at ASC`,
            [id]
        )
        res.json(rows)
    } catch (err) {
        console.error(err)
        res.status(500).json({ error: 'Server error' })
    }
})

module.exports = router
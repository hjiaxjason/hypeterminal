const express = require('express')
const router = express.Router()
const pool = require('../config/db')

// GET /items — all items, with optional filters
router.get('/', async (req, res) => {
  try {
    const { category, brand } = req.query

    let query = 'SELECT * FROM items'
    let params = []
    let conditions = []

    if (category) {
      conditions.push(`category = $${params.length + 1}`)
      params.push(category)
    }

    if (brand) {
      conditions.push(`brand = $${params.length + 1}`)
      params.push(brand)
    }

    if (conditions.length > 0) {
      query += ' WHERE ' + conditions.join(' AND ')
    }

    query += ' ORDER BY name'

    const { rows } = await pool.query(query, params)
    res.json(rows)
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Server error' })
  }
})

// GET /items/:id — single item detail
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params
    const { rows } = await pool.query(
      'SELECT * FROM items WHERE id = $1',
      [id]
    )
    if (rows.length === 0) return res.status(404).json({ error: 'Not found' })
    res.json(rows[0])
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Server error' })
  }
})

// GET /items/:id/prices — price history for one item
router.get('/:id/prices', async (req, res) => {
  try {
    const { id } = req.params
    const { rows } = await pool.query(
      `SELECT * FROM price_history
       WHERE sneaker_id = $1
       ORDER BY recorded_at ASC`,
      [id]
    )
    if (rows.length === 0) return res.status(404).json({ error: 'No price history found' })
    res.json(rows)
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Server error' })
  }
})

module.exports = router
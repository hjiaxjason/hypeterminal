const express = require('express')
const router = express.Router()
const supabase = require('../config/supabase')

// GET /items — all items, with optional filters
router.get('/', async (req, res) => {
  try {
    const { category, brand } = req.query

    let query = supabase.from('items').select('*').order('name')

    if (category) query = query.eq('category', category)
    if (brand)    query = query.eq('brand', brand)

    const { data, error } = await query

    if (error) throw error
    res.json(data)
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Server error' })
  }
})

// GET /items/:id — single item detail
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params

    const { data, error } = await supabase
      .from('items')
      .select('*')
      .eq('id', id)
      .single()

    if (error) return res.status(404).json({ error: 'Not found' })
    res.json(data)
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Server error' })
  }
})

// GET /items/:id/prices — price history for one item
router.get('/:id/prices', async (req, res) => {
  try {
    const { id } = req.params

    const { data, error } = await supabase
      .from('price_history')
      .select('*')
      .eq('item_id', id)        // was sneaker_id — bug fix
      .order('recorded_at', { ascending: true })

    if (error) throw error
    if (!data || data.length === 0) {
      return res.status(404).json({ error: 'No price history found' })
    }
    res.json(data)
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Server error' })
  }
})

module.exports = router
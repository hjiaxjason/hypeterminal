const express = require('express')
const router = express.Router()
const supabase = require('../config/supabase')

// GET /indexes — all indexes
router.get('/', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('indexes')
      .select('*')

    if (error) throw error
    res.json(data)
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Server error' })
  }
})

// GET /indexes/:id — single index detail + its members
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params

    const { data, error } = await supabase
      .from('indexes')
      .select(`
        *,
        index_members (
          weight,
          items (id, name, brand, category, image_url)
        )
      `)
      .eq('id', id)
      .single()

    if (error) return res.status(404).json({ error: 'Not found' })
    res.json(data)
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Server error' })
  }
})

// GET /indexes/:id/history — index value over time
router.get('/:id/history', async (req, res) => {
  try {
    const { id } = req.params

    const { data, error } = await supabase
      .from('index_history')
      .select('*')
      .eq('index_id', id)
      .order('recorded_at', { ascending: true })

    if (error) throw error
    res.json(data)
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Server error' })
  }
})

module.exports = router
const express = require('express')
const router = express.Router()
const supabase = require('../config/supabase')

// GET /auth/google — redirect to Google login
router.get('/google', async (req, res) => {
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: 'http://localhost:3000/auth/callback'
    }
  })

  if (error) return res.status(500).json({ error: error.message })
  res.redirect(data.url)
})

// GET /auth/callback — Google redirects here after login
router.get('/callback', async (req, res) => {
  try {
    const { code } = req.query

    const { data, error } = await supabase.auth.exchangeCodeForSession(code)
    if (error) return res.status(400).json({ error: error.message })

    const { user, session } = data

    // Upsert user into our public.users table
    const { error: upsertError } = await supabase
      .from('users')
      .upsert(
        {
          id:       user.id,
          email:    user.email,
          username: user.email.split('@')[0]
        },
        { onConflict: 'id' }
      )

    if (upsertError) console.error('User upsert error:', upsertError)

    res.redirect(`http://localhost:5173/auth/success?token=${session.access_token}`)
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Server error' })
  }
})

// POST /auth/email/signup — sign up with email
router.post('/email/signup', async (req, res) => {
  try {
    const { email, password } = req.body

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' })
    }

    const { data, error } = await supabase.auth.signUp({ email, password })
    if (error) return res.status(400).json({ error: error.message })

    const user = data.user

    // User row is created after email confirmation in production.
    // We insert optimistically here — ON CONFLICT handles duplicates.
    const { error: upsertError } = await supabase
      .from('users')
      .upsert(
        {
          id:       user.id,
          email:    user.email,
          username: user.email.split('@')[0]
        },
        { onConflict: 'id' }
      )

    if (upsertError) console.error('User upsert error:', upsertError)

    res.status(201).json({
      message: 'Check your email to confirm your account',
      user: { id: user.id, email: user.email }
    })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Server error' })
  }
})

// POST /auth/email/login — login with email
router.post('/email/login', async (req, res) => {
  try {
    const { email, password } = req.body

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' })
    }

    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    })

    if (error) return res.status(401).json({ error: 'Invalid credentials' })

    res.json({
      user: {
        id:    data.user.id,
        email: data.user.email
      },
      token: data.session.access_token
    })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Server error' })
  }
})

// GET /auth/me — get current user from token
router.get('/me', async (req, res) => {
  try {
    const authHeader = req.headers.authorization
    if (!authHeader) return res.status(401).json({ error: 'No token provided' })

    const token = authHeader.split(' ')[1]

    // Verify token and get user from Supabase Auth
    const { data: authData, error: authError } = await supabase.auth.getUser(token)
    if (authError) return res.status(401).json({ error: 'Invalid token' })

    // Fetch the matching row from our public.users table
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('id, email, username')
      .eq('id', authData.user.id)   // bug fix: was data.user_id, should be authData.user.id
      .single()

    if (userError) return res.status(404).json({ error: 'User not found' })

    res.json(user)
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Server error' })
  }
})

module.exports = router
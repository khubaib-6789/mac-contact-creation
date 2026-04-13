import express from 'express'
import { exec } from 'child_process'
import { writeFile, unlink } from 'fs/promises'
import { randomUUID } from 'crypto'
import os from 'os'
import path from 'path'

const app = express()
const PORT = 1299
const API_KEY = process.env.API_KEY

app.use(express.json())

app.use((req, res, next) => {
  if (req.headers['x-api-key'] !== API_KEY)
    return res.status(403).json({ error: 'Forbidden' })
  next()
})

app.post('/create-contact', async (req, res) => {
  const { user, firstName, lastName, email, phone } = req.body

  if (!user || !firstName || !lastName || !email || !phone)
    return res.status(400).json({ error: 'Missing required fields' })

  const script = `tell application "Contacts"
    set newPerson to make new person with properties {first name:"${firstName}", last name:"${lastName}"}
    tell newPerson
        make new email with properties {label:"work", value:"${email}"}
        make new phone with properties {label:"mobile", value:"${phone}"}
    end tell
    save
    return "Contact created successfully"
end tell`

  const tmpFile = path.join(os.tmpdir(), `contact-${randomUUID()}.scpt`)

  try {
    await writeFile(tmpFile, script)
    const cmd = `sudo -u ${user} env -i HOME=/Users/${user} osascript ${tmpFile}`

    exec(cmd, async (err, stdout, stderr) => {
      await unlink(tmpFile).catch(() => {})
      if (err) return res.status(500).json({ error: stderr })
      res.json({ success: true, message: stdout.trim() })
    })
  } catch (err) {
    await unlink(tmpFile).catch(() => {})
    res.status(500).json({ error: String(err) })
  }
})

app.listen(PORT, () => console.log(`Agent running on :${PORT}`))
const express = require('express')
const axios = require('axios')
const ejs = require('ejs')

const PORT = process.env.PORT || 80

const app = express()
app.set('views', 'views')
app.set('view engine', 'ejs')
app.use(express.static('public'))

app.locals.version = require('./package.json').version

app.get('/', async (req, res) => {

    let address
    if (process.env.NODE_ENV == 'production') {
        try {
            const result = await axios.get('http://169.254.170.2/v2/metadata')
            const container = result.data.Containers.find(e => e.Image.includes('tinyproxy') == false)
            address = container.Networks[0].IPv4Addresses[0]
        } catch (err) {}
    }
    if (address == null) address = '10.10.10.10'

    res.render('index', { address })
})

app.listen(PORT, () => {
    console.log(`listening on port ${PORT}`)
})
// Diagram export only. Uses the bundled librsvg renderer through Sharp.
const path = require('node:path');
const sharp = require(process.env.SHARP_MODULE || 'sharp');
sharp(path.join(__dirname,'vectorcgra-architecture.svg'),{density:108})
  .png().toFile(path.join(__dirname,'vectorcgra-architecture.png'))
  .then(info=>console.log(JSON.stringify(info)))
  .catch(error=>{console.error(error);process.exit(1)});
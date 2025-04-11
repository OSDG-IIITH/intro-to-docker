import express from "express"
import fs from "fs"

const app = express()

function ord(num: number) {
  let ret = num.toString()
  switch (num % 10) {
    case 1:
      ret += "st"
      break;
    case 2:
      ret += "nd"
      break;
    case 3:
      ret += "rd"
      break;
    default:
      ret += "th"
      break;
  }
  return ret
}

app.get("/", (_, res) => {
  let count = 0;
  if (fs.existsSync("./count")) 
    count = Number(fs.readFileSync("./count").toString())
  fs.writeFileSync("./count", (++count).toString());
  res.send(`<h1>Hello, world!</h1><p>You're the ${ord(count)} view.`);
})

process.addListener("SIGINT", () => {
  process.exit(0);
})

const PORT = Number(process.env.PORT || "5000")
console.log(`Starting server at http://localhost:${PORT}`)
app.listen(PORT)

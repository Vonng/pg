title = $$("h1.entry-title")[0].innerText;
meta = title.match(/^(\d+).刘仲敬访谈第(\d+)集$/)
no = meta[2]
ds = meta[1]
titleString = '# ' + no + ' ' + ds

// meta = $$('meta[name="description"]')[0].getAttribute("content");
content = $$("div.entry-content")[0].innerText;
lines = content.split('\n\n')
for (var i = 0; i < lines.length; i++) {
    line = lines[i]
    match = line.match(/^\[[0-9:]+\]/)
    if (match !== undefined) {
        lines[i] = line.replace(/^\[[0-9:]+\]/, "")
    }
}
content = lines.join('\n\n')

result = titleString + '\n\n\n\n' + content;
copy(result);
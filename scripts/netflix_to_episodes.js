// Go to http://api.netflix.com/catalog/titles/series/<show ID>/episodes
// open DevTools and run this function with an array of season lengths
// Paste the result into your manifest.json episodes

async function process(seasons) {
  let text = await (await fetch(window.location.href)).text();
  let parser = new DOMParser();
  let doc = parser.parseFromString(text,"text/xml").documentElement;
  let titleEls = Array.from(doc.querySelectorAll('title'));
  let idEls = Array.from(doc.querySelectorAll('id'));
  let titles = titleEls.map((i) => i.attributes.regular.value);
  let ids = idEls.map((i) => i.textContent.split('/')[6]);
  let data = {};
  let season = 1;
  let episode = 1;
  let i = 0;
  while (seasons.length) {
    if (episode > seasons[0]) {
      season++;
      episode = 1;
      seasons.shift();
    } else {
      data[`${season}${episode < 10 ? '0': ''}${episode}`] =
        {'title': titles[i], 'netflix': ids[i]};
      episode++;
      i++;
    }
  }
  return JSON.stringify(data);
}
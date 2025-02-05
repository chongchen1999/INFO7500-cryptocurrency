import re
import sys
import urllib.request
import modal

app = modal.App(name="chongchen-web-scraper")


@app.function()
def get_links(url):
    response = urllib.request.urlopen(url)
    html = response.read().decode("utf8")
    links = []
    for match in re.finditer('href="(.*?)"', html):
        links.append(match.group(1))
    return links


@app.local_entrypoint()
def main(url):
    links = get_links.remote(url)
    print(links)


if __name__ == "__main__":
    url = sys.argv[1] if len(sys.argv) > 1 else "https://news.yahoo.com"
    links = get_links(url)
    print(links)
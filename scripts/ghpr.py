#!/usr/bin/env python3
from flask import Flask, jsonify
import requests
import subprocess
import json

app = Flask(__name__)

@app.route('/prs', methods=['GET'])
def get_prs():
    # URL de l'API GitHub
    url = "https://api.github.com/repos/opensvc/om3/pulls?state=open"
    headers = {"Accept": "application/vnd.github+json"}

    try:
        # Requête à l'API GitHub
        response = requests.get(url, headers=headers)
        response.raise_for_status()  # Vérifie les erreurs HTTP

        # Parser le JSON et formater en {name: "...", value: "..."}
        prs = response.json()
        formatted_prs = [
            {"name": f"[{pr['number']}] {pr['title']}", "value": f"pull/{pr['number']}"}
            for pr in prs
        ]

        # Renvoie le payload au format JSON
        return jsonify(formatted_prs)

    except requests.exceptions.RequestException as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
##            {"name": f"[{pr['number']}] {pr['title']}", "value": str(pr["number"])}

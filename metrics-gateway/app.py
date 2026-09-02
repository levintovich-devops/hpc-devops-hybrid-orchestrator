import re
import sys

from flask import Flask, Response, jsonify, request

app = Flask(__name__)

METRIC_NAME_RE = re.compile(r"^[a-zA-Z_:][a-zA-Z0-9_:]*$")
LABEL_NAME_RE = re.compile(r"^[a-zA-Z_][a-zA-Z0-9_]*$")
metrics = {}


def _escape_label_value(value):
    return str(value).replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')


def _validate_metric_name(metric_name):
    if not isinstance(metric_name, str) or not METRIC_NAME_RE.fullmatch(metric_name):
        return False
    return True


def _validate_label_name(label_name):
    if not isinstance(label_name, str) or not LABEL_NAME_RE.fullmatch(label_name):
        return False
    return True


@app.route("/update-metric", methods=["PUT"])
def update_metric():
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"error": "JSON object required"}), 400

    metric_name = payload.get("metric_name")
    value = payload.get("value")
    labels = payload.get("labels", {})

    if not _validate_metric_name(metric_name):
        return jsonify({"error": "invalid metric name"}), 400

    if value is None or isinstance(value, bool):
        return jsonify({"error": "numeric value required"}), 400

    try:
        numeric_value = float(value)
    except (TypeError, ValueError):
        return jsonify({"error": "value must be numeric"}), 400

    if not isinstance(labels, dict):
        return jsonify({"error": "labels must be an object"}), 400

    normalized_labels = {}
    for label_name, label_value in labels.items():
        if not _validate_label_name(label_name):
            return jsonify({"error": "invalid label name"}), 400
        normalized_labels[str(label_name)] = str(label_value)

    key = (metric_name, tuple(sorted(normalized_labels.items())))
    metrics[key] = {
        "metric_name": metric_name,
        "labels": normalized_labels,
        "value": numeric_value,
    }
    return jsonify({"status": "ok"})


@app.route("/metrics", methods=["GET"])
def metrics_endpoint():
    lines = []
    for entry in metrics.values():
        metric_name = entry["metric_name"]
        labels = entry["labels"]
        if labels:
            label_pairs = ", ".join(
                f'{label_name}="{_escape_label_value(label_value)}"'
                for label_name, label_value in sorted(labels.items())
            )
            lines.append(f"{metric_name}{{{label_pairs}}} {entry['value']}")
        else:
            lines.append(f"{metric_name} {entry['value']}")

    response = "\n".join(lines)
    if response:
        response += "\n"

    return Response(response, content_type="text/plain; version=0.0.4; charset=utf-8")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)

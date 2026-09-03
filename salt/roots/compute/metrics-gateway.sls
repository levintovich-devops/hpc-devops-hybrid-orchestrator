{% set gateway = salt['pillar.get']('metrics_gateway') %}
{% set image = gateway['image'] %}
{% set artifact = gateway['artifact'] %}
{% set release = gateway['release'] %}
{% set chart = gateway['chart'] %}
{% set service = gateway['service'] %}
{% set monitor = gateway['service_monitor'] %}
{% set image_ref = image['repository'] ~ ':' ~ image['tag'] %}
{% set archive_path = artifact['root'] ~ '/' ~ image['name'] ~ '-' ~ image['tag'] ~ '.tar' %}
{% set values_path = '/var/lib/rancher/k3s/metrics-gateway-values.yaml' %}
{% set image_marker_path = '/var/lib/rancher/k3s/metrics-gateway-image.signature' %}
{% set release_marker_path = '/var/lib/rancher/k3s/metrics-gateway-release.signature' %}

metrics-gateway-values:
  file.managed:
    - name: {{ values_path }}
    - contents: |
        replicaCount: 1
        image:
          repository: {{ image['repository'] | json }}
          tag: {{ image['tag'] | json }}
          pullPolicy: Never
        service:
          type: ClusterIP
          port: {{ service['port'] }}
        containerPort: {{ service['container_port'] }}
        serviceMonitor:
          enabled: {{ monitor['enabled'] | lower }}
          interval: {{ monitor['interval'] | json }}
          labels:
            release: {{ monitor['release_label'] | json }}
    - user: root
    - group: root
    - mode: 0644
    - require:
        - cmd: k3s-ready

metrics-gateway-image-import:
  cmd.run:
    - name: >-
        set -eu; archive={{ archive_path | json }}; image={{ image_ref | json }};
        test -s "$archive";
        archive_hash=$(sha256sum "$archive" | awk '{print $1}');
        signature="${archive_hash}|${image}";
        if test -f {{ image_marker_path | json }} && grep -Fqx "$signature" {{ image_marker_path | json }} && /usr/local/bin/k3s ctr --namespace k8s.io images list -q | grep -Fqx "$image"; then exit 0; fi;
        /usr/local/bin/k3s ctr --namespace k8s.io images import "$archive";
        if ! /usr/local/bin/k3s ctr --namespace k8s.io images list -q | grep -Fqx "$image"; then
          echo "Expected imported image $image was not found in k8s.io" >&2;
          exit 1;
        fi;
        test -d "$(dirname {{ image_marker_path | json }})" || install -d -m 0755 "$(dirname {{ image_marker_path | json }})";
        temporary_marker={{ (image_marker_path ~ '.tmp') | json }}.$$;
        printf '%s\n' "$signature" > "$temporary_marker";
        mv "$temporary_marker" {{ image_marker_path | json }}
    - unless: >-
        test -s {{ archive_path | json }}
        && test -f {{ image_marker_path | json }}
        && test "$(sha256sum {{ archive_path | json }} | awk '{print $1}')|{{ image_ref }}" = "$(cat {{ image_marker_path | json }})"
        && /usr/local/bin/k3s ctr --namespace k8s.io images list -q | grep -Fqx {{ image_ref | json }}
    - require:
        - cmd: k3s-ready

metrics-gateway:
  cmd.run:
    - name: >-
        set -eu; chart_hash=$(find {{ chart['path'] | json }} -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | awk '{print $1}');
        values_hash=$(sha256sum {{ values_path | json }} | awk '{print $1}');
        image_signature=$(cat {{ image_marker_path | json }});
        requested_signature="${chart_hash}|${values_hash}|${image_signature}|{{ image['tag'] }}|{{ release['name'] }}";
        if test -f {{ release_marker_path | json }} && grep -Fqx "$requested_signature" {{ release_marker_path | json }} && helm status {{ release['name'] }} --namespace {{ release['namespace'] }} --kubeconfig /etc/rancher/k3s/k3s.yaml --output json | tr -d '[:space:]' | grep -Fq '"status":"deployed"'; then exit 0; fi;
        helm upgrade --install {{ release['name'] }} {{ chart['path'] }} --namespace {{ release['namespace'] }} --create-namespace --kubeconfig /etc/rancher/k3s/k3s.yaml --values {{ values_path }} --set-string image.archiveSignature="$image_signature" --wait --timeout 5m;
        temporary_marker={{ (release_marker_path ~ '.tmp') | json }}.$$;
        printf '%s\n' "$requested_signature" > "$temporary_marker";
        mv "$temporary_marker" {{ release_marker_path | json }}
    - unless: >-
        test -f {{ release_marker_path | json }}
        && test "$(find {{ chart['path'] | json }} -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | awk '{print $1}')|$(sha256sum {{ values_path | json }} | awk '{print $1}')|$(cat {{ image_marker_path | json }})|{{ image['tag'] }}|{{ release['name'] }}" = "$(cat {{ release_marker_path | json }})"
        && helm status {{ release['name'] }} --namespace {{ release['namespace'] }} --kubeconfig /etc/rancher/k3s/k3s.yaml --output json | tr -d '[:space:]' | grep -Fq '"status":"deployed"'
    - require:
        - cmd: k3s-ready
        - cmd: helm-install
        - cmd: monitoring-stack
        - cmd: metrics-gateway-image-import
        - file: metrics-gateway-values

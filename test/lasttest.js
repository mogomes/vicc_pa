// Lasttest fuer die Praxisarbeit VICC (k6, https://grafana.com/docs/k6/latest/)
// Aufruf (Git Bash):  MSYS_NO_PATHCONV=1 k6 run -e TARGET="https://<app-fqdn>/health" test/lasttest.js
// 120 virtuelle Benutzer in geschlossener Schleife; Scale-Regel: 20 gleichzeitige Requests je Replica.
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  vus: 120,
  duration: '4m',
  thresholds: { http_req_failed: ['rate<0.05'] },
};

export default function () {
  const res = http.get(__ENV.TARGET);
  check(res, { 'status 200': (r) => r.status === 200 });
}

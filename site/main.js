/* PangoLock site: armored scale-ball hero + small scroll interactions. No dependencies. */
(() => {
  "use strict";
  const reduceMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const finePointer = matchMedia("(pointer: fine)").matches;

  /* ───────── Scale ball: a Fibonacci sphere of pangolin scales ───────── */
  const canvas = document.getElementById("scales");
  const ctx = canvas.getContext("2d");
  const toggle = document.getElementById("lockToggle");
  const N = 460;
  const GOLDEN = Math.PI * (3 - Math.sqrt(5));
  const LIGHT = norm([-0.5, -0.6, 0.65]);
  const scales = [];

  for (let i = 0; i < N; i++) {
    const y = 1 - (i / (N - 1)) * 2;
    const r = Math.sqrt(1 - y * y);
    const th = i * GOLDEN;
    const n = [Math.cos(th) * r, y, Math.sin(th) * r];
    // "Down the body": tangent pointing toward the south pole, so scales overlap like armor.
    let t = [-n[0] * n[1], 1 - n[1] * n[1], -n[2] * n[1]];
    const tl = Math.hypot(t[0], t[1], t[2]);
    t = tl < 1e-3 ? [1, 0, 0] : t.map((v) => v / tl);
    scales.push({ n, t, b: cross(n, t), phase: Math.random() * Math.PI * 2, p: [0, 0, 0], z: 0 });
  }

  let W = 0, H = 0, dpr = 1, cx = 0, cy = 0, R = 0;
  let yaw = 0.6, pitch = -0.35, vy = 0.0035;
  let mx = 0, my = 0, tmx = 0, tmy = 0;
  let locked = false, lockAmt = 0, flash = 0, scrollCurl = 0;
  let running = true, last = performance.now(), time = 0;

  function resize() {
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    W = canvas.clientWidth; H = canvas.clientHeight;
    canvas.width = W * dpr; canvas.height = H * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    const mobile = W < 720;
    cx = mobile ? W * 0.5 : W * 0.74;
    cy = mobile ? H * 0.3 : H * 0.52;
    R = mobile ? Math.min(W * 0.36, H * 0.2) : Math.min(W * 0.19, H * 0.3);
  }

  function frame(now) {
    const dt = Math.min(now - last, 50) / 16.67;
    last = now; time += dt;
    mx += (tmx - mx) * 0.05 * dt; my += (tmy - my) * 0.05 * dt;
    lockAmt += ((locked ? 1 : 0) - lockAmt) * 0.06 * dt;
    flash = Math.max(0, flash - 0.02 * dt);

    const curl = Math.min(1, Math.max(lockAmt, scrollCurl));
    yaw += vy * dt * (1 + curl * 2.5);
    const ry = yaw + mx * 0.6, rx = pitch + my * 0.4;
    const cyw = Math.cos(ry), syw = Math.sin(ry), cp = Math.cos(rx), sp = Math.sin(rx);
    const rot = (v) => {
      const x = v[0] * cyw + v[2] * syw, z = -v[0] * syw + v[2] * cyw;
      return [x, v[1] * cp - z * sp, v[1] * sp + z * cp];
    };

    ctx.clearRect(0, 0, W, H);

    // Ambient glow behind the ball, greener when locked.
    const g = ctx.createRadialGradient(cx, cy, R * 0.2, cx, cy, R * 2.1);
    g.addColorStop(0, `rgba(${lerp(200, 92, lockAmt * 0.5)|0},${lerp(148, 197, lockAmt * 0.5)|0},${lerp(90, 138, lockAmt * 0.5)|0},${0.22 + flash * 0.3})`);
    g.addColorStop(1, "rgba(18,13,9,0)");
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);

    const focal = 3.2;
    const breathe = 1 + Math.sin(time * 0.03) * 0.012 * (1 - curl);
    for (const s of scales) {
      // Open scales lift off the body and flutter; locked scales clamp shut.
      const lift = (1 - curl) * (0.05 + 0.035 * Math.sin(time * 0.05 + s.phase + s.n[1] * 4));
      const rad = (1 + lift) * breathe;
      const n = rot(s.n);
      s.z = n[2];
      const k = focal / (focal - n[2] * rad);
      s.p = [cx + n[0] * rad * R * k, cy + n[1] * rad * R * k, k];
      s.rn = n;
      s.rt = rot(s.t);
      s.rb = rot(s.b);
    }
    scales.sort((a, b) => a.z - b.z);

    const size = R * lerp(0.11, 0.155, curl);
    for (const s of scales) {
      const n = s.rn;
      if (n[2] < -0.25) continue;
      const [px, py, k] = s.p;
      const L = size * 1.25 * k, Wd = size * 0.78 * k;
      // Projected tangent frame gives foreshortening for free. Open scales tilt outward.
      const tilt = (1 - curl) * 0.35;
      const tx = (s.rt[0] + n[0] * tilt) * L, ty = (s.rt[1] + n[1] * tilt) * L;
      const bx = s.rb[0] * Wd, by = s.rb[1] * Wd;

      const lambert = Math.max(0, dot(n, LIGHT));
      const rim = Math.pow(1 - Math.abs(n[2]), 3);
      const fade = Math.min(1, (n[2] + 0.25) * 3);
      const l = 0.22 + lambert * 0.85 + flash * 0.4;
      const r = clamp(lerp(70, 232, l) + rim * 40), gg = clamp(lerp(42, 186, l) + rim * 20), bb = clamp(lerp(22, 120, l * 0.9));

      ctx.beginPath();
      ctx.moveTo(px - tx * 0.35 + bx, py - ty * 0.35 + by);
      ctx.quadraticCurveTo(px + bx * 1.05 + tx * 0.55, py + by * 1.05 + ty * 0.55, px + tx, py + ty);
      ctx.quadraticCurveTo(px - bx * 1.05 + tx * 0.55, py - by * 1.05 + ty * 0.55, px - tx * 0.35 - bx, py - ty * 0.35 - by);
      ctx.quadraticCurveTo(px - tx * 0.75, py - ty * 0.75, px - tx * 0.35 + bx, py - ty * 0.35 + by);
      ctx.closePath();
      ctx.globalAlpha = fade;
      const sg = ctx.createLinearGradient(px - tx * 0.35, py - ty * 0.35, px + tx, py + ty);
      sg.addColorStop(0, `rgb(${r},${gg},${bb})`);
      sg.addColorStop(1, `rgb(${r * 0.55 | 0},${gg * 0.5 | 0},${bb * 0.45 | 0})`);
      ctx.fillStyle = sg;
      ctx.fill();
      ctx.lineWidth = Math.max(0.6, k * 0.9);
      ctx.strokeStyle = `rgba(30,18,10,${0.55 + curl * 0.2})`;
      ctx.stroke();
      // Center ridge on each scale.
      if (n[2] > 0.15) {
        ctx.beginPath();
        ctx.moveTo(px - tx * 0.2, py - ty * 0.2);
        ctx.lineTo(px + tx * 0.75, py + ty * 0.75);
        ctx.strokeStyle = `rgba(255,232,190,${0.12 + lambert * 0.22})`;
        ctx.lineWidth = Math.max(0.5, k * 0.7);
        ctx.stroke();
      }
    }
    ctx.globalAlpha = 1;

    // Lock ring when sealed.
    if (lockAmt > 0.02 || flash > 0) {
      ctx.beginPath();
      ctx.arc(cx, cy, R * (1.32 + (1 - lockAmt) * 0.2 + flash * 0.25), 0, Math.PI * 2);
      ctx.strokeStyle = `rgba(92,197,138,${lockAmt * 0.35 + flash * 0.5})`;
      ctx.lineWidth = 1.5;
      ctx.setLineDash([4, 10]);
      ctx.lineDashOffset = -time * 0.6;
      ctx.stroke();
      ctx.setLineDash([]);
    }

    if (running && !reduceMotion) requestAnimationFrame(frame);
  }

  function start() { if (!running) { running = true; last = performance.now(); requestAnimationFrame(frame); } }

  resize();
  addEventListener("resize", resize);
  requestAnimationFrame(frame);
  new IntersectionObserver(([e]) => { if (e.isIntersecting) start(); else running = false; }).observe(canvas);

  addEventListener("pointermove", (e) => {
    tmx = (e.clientX / innerWidth - 0.5) * 2;
    tmy = (e.clientY / innerHeight - 0.5) * 2;
  }, { passive: true });
  addEventListener("scroll", () => {
    scrollCurl = Math.min(1, scrollY / (innerHeight * 0.6));
  }, { passive: true });

  toggle.addEventListener("click", () => {
    locked = !locked;
    flash = 1;
    toggle.setAttribute("aria-pressed", String(locked));
    toggle.querySelector("span").textContent = locked ? "Locked. Unroll?" : "Lock the ball";
    if (reduceMotion) requestAnimationFrame(frame);
  });

  /* ───────── Reveal on scroll ───────── */
  const io = new IntersectionObserver((entries) => {
    for (const e of entries) if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); }
  }, { threshold: 0.15, rootMargin: "0px 0px -40px 0px" });
  document.querySelectorAll(".reveal").forEach((el) => io.observe(el));

  /* ───────── 3D tilt + spotlight ───────── */
  if (finePointer && !reduceMotion) {
    document.querySelectorAll("[data-tilt]").forEach((el) => {
      const max = el.classList.contains("window") ? 5 : 9;
      el.addEventListener("pointermove", (e) => {
        const r = el.getBoundingClientRect();
        const x = (e.clientX - r.left) / r.width, y = (e.clientY - r.top) / r.height;
        el.style.transform = `rotateY(${(x - 0.5) * max}deg) rotateX(${(0.5 - y) * max}deg) translateZ(0)`;
        el.style.setProperty("--mx", `${x * 100}%`);
        el.style.setProperty("--my", `${y * 100}%`);
      });
      el.addEventListener("pointerleave", () => { el.style.transform = ""; });
    });
  }

  /* ───────── Counters ───────── */
  const fmt = new Intl.NumberFormat("en-US");
  const countIO = new IntersectionObserver((entries) => {
    for (const e of entries) {
      if (!e.isIntersecting) continue;
      countIO.unobserve(e.target);
      const end = +e.target.dataset.count, t0 = performance.now(), dur = 1600;
      const tick = (now) => {
        const p = reduceMotion ? 1 : Math.min(1, (now - t0) / dur);
        e.target.textContent = fmt.format(Math.round(end * (1 - Math.pow(1 - p, 4))));
        if (p < 1) requestAnimationFrame(tick);
      };
      requestAnimationFrame(tick);
    }
  }, { threshold: 0.6 });
  document.querySelectorAll("[data-count]").forEach((el) => countIO.observe(el));

  /* ───────── Pipeline line + plaintext → ciphertext scramble ───────── */
  const pipeline = document.getElementById("pipeline");
  new IntersectionObserver(([e], o) => { if (e.isIntersecting) { pipeline.classList.add("in"); o.disconnect(); } }, { threshold: 0.35 }).observe(pipeline);

  const cipherEl = document.getElementById("cipherText");
  const plain = ["~/Documents/TripsAndTours", "~/Desktop/Tax Filing - 2025", "~/Pictures/Family"];
  const HEX = "0123456789abcdef";
  const randHex = (n) => Array.from({ length: n }, () => HEX[(Math.random() * 16) | 0]).join("");
  let ci = 0;
  function scramble(from, to, done) {
    const len = Math.max(from.length, to.length);
    let f = 0;
    const step = () => {
      f++;
      let out = "";
      for (let i = 0; i < len; i++) {
        if (i < f - 6) out += to[i] || "";
        else if (i < f) out += HEX[(Math.random() * 16) | 0];
        else out += from[i] || "";
      }
      cipherEl.textContent = out;
      if (f < len + 6) setTimeout(step, 28); else { cipherEl.textContent = to; done && done(); }
    };
    step();
  }
  function cycle() {
    const p = plain[ci++ % plain.length];
    const c = "🔒 " + randHex(8) + "·" + randHex(24) + ".plock";
    scramble(cipherEl.textContent, p, () => setTimeout(() => scramble(p, c, () => setTimeout(cycle, 2200)), 1400));
  }
  if (!reduceMotion) {
    new IntersectionObserver(([e], o) => { if (e.isIntersecting) { o.disconnect(); cycle(); } }, { threshold: 0.5 }).observe(cipherEl);
  }

  /* ───────── Copy buttons ───────── */
  document.querySelectorAll("[data-copy]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(document.getElementById(btn.dataset.copy).innerText);
        btn.textContent = "Copied"; btn.classList.add("done");
      } catch { btn.textContent = "Select & copy"; }
      setTimeout(() => { btn.textContent = "Copy"; btn.classList.remove("done"); }, 1800);
    });
  });

  /* ───────── Live star count ───────── */
  const starEl = document.querySelector("[data-stars]");
  const showStars = (n) => { if (typeof n === "number") starEl.textContent = `★ ${fmt.format(n)}`; };
  let cached = null;
  try { cached = JSON.parse(sessionStorage.getItem("pl-stars")); } catch {}
  if (cached) showStars(cached);
  else fetch("https://api.github.com/repos/suriya4code/PangoLock")
    .then((r) => (r.ok ? r.json() : null))
    .then((d) => { if (d) { showStars(d.stargazers_count); try { sessionStorage.setItem("pl-stars", d.stargazers_count); } catch {} } })
    .catch(() => {});

  /* ───────── helpers ───────── */
  function norm(v) { const l = Math.hypot(...v); return v.map((x) => x / l); }
  function cross(a, b) { return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]; }
  function dot(a, b) { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }
  function lerp(a, b, t) { return a + (b - a) * t; }
  function clamp(v) { return Math.max(0, Math.min(255, v | 0)); }
})();

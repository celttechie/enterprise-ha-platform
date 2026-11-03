# Demonstration Runbook & Media Recording Guide

Step-by-step procedures for executing live High Availability drills, synthetic load surges, and capturing publication-quality screenshots and videos.

---

## 1. Pre-Flight Preparation

Before recording or presenting:
1. Verify workstation tooling:
   ```bash
   make doctor
   ```
2. Confirm cluster connectivity:
   ```bash
   kubectl get nodes -o wide
   ```
3. Open two terminal windows or configure a split-pane layout (e.g. using `tmux` or multiple terminal panes):
   * **Pane 1 (Left):** `k9s` or `watch -n 1 'kubectl get pods -o wide'`
   * **Pane 2 (Top Right):** Load generation runner (`k6 run workloads/load-tests/surge.js`)
   * **Pane 3 (Bottom Right):** Chaos trigger console

---

## 2. Step-by-Step Demonstration Flow

### Step 1: Baseline Steady State
* Deploy baseline application (2 replicas distributed across different nodes/AZs).
* Confirm anti-affinity rules prevent co-location.

### Step 2: Traffic Surge (Scalability Trigger)
* Launch synthetic traffic ramp:
  ```bash
  k6 run --vus 500 --duration 2m workloads/load-tests/surge.js
  ```
* **Observation:** In `k9s`, observe KEDA / Metrics-Server detecting load and scaling replicas from 2 $\rightarrow$ 6 $\rightarrow$ 15+.
* **Metric Check:** P95 latency remains stable under SLA.

### Step 3: Failure Injection (High Availability Drill)
While traffic is at its peak:
* **On Local KVM:**
  ```bash
  virsh destroy <target-worker-vm>
  ```
* **On AWS (EKS Spot):**
  ```bash
  aws ec2 terminate-instances --instance-ids <target-instance-id>
  ```
* **Observation:** The target node transitions to `NotReady`. Pods residing on that node enter `Terminating` and are instantly reconstituted on surviving worker nodes.
* **Result Verification:** `k6` logs show `0.00%` failed HTTP requests.

---

## 3. Media Capture & Post-Processing

### Recording Terminal Animation with `ffmpeg`:
To capture high-resolution MP4/GIFs of the terminal demonstration:
```bash
# Record X11 terminal screen region to MP4
ffmpeg -f x11grab -video_size 1280x720 -i :0.0+100,100 -codec:v libx264 -preset ultrafast recordings/ha-drill.mp4

# Convert MP4 to web-optimized GIF
ffmpeg -i recordings/ha-drill.mp4 -vf "fps=15,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" recordings/ha-drill.gif
```

### Staging Captured Media:
Move all raw screenshots and exported GIFs into the central staging directory:
```bash
cp recordings/*.gif ~/Projects/lab-docs/content-staging/
```

# Deployment Changes - October 3, 2025

## Summary

Updated Granite 4.0 deployment to follow a proven Docker deployment pattern. The new structure provides:

1. ✅ **Persistent storage** - Models and logs survive container restarts
2. ✅ **Automatic restart** - Service restarts unless explicitly stopped
3. ✅ **Single-command deployment** - `./deploy.sh` does everything
4. ✅ **Comprehensive management** - `./manage.sh` with all common operations
5. ✅ **H-Tiny by default** - Using 7B/1B MoE instead of 3B

## What Changed

### 1. Model Selection
- **Before**: H-Micro (3B dense)
- **After**: H-Tiny (7B/1B MoE)
- **Reason**: Better quality with plenty of CPU/RAM available

### 2. Deployment Method
- **Before**: `docker-compose` based with separate build/start commands
- **After**: Direct `docker run` with single `./deploy.sh` command
- **Pattern**: Simplified single-script deployment

### 3. Persistent Storage
- **Before**: Models downloaded inside container (lost on rebuild)
- **After**: Models stored in `./models/` directory (persists)
- **Benefit**: No re-download on container rebuild (~4.5GB saved)

```bash
granite-4.0/
├── models/              # ✨ NEW - Persistent model storage
│   └── granite-4.0-h-tiny.gguf
└── logs/                # ✨ NEW - Persistent logs
```

### 4. Restart Policy
- **Before**: Manual restart after reboot
- **After**: `--restart unless-stopped` (auto-restart)
- **Benefit**: Survives server reboots automatically

### 5. Management Scripts

#### deploy.sh (Simplified)
- **Before**: Multi-command (build|start|stop|restart|logs|test|status)
- **After**: Single-purpose deployment script
- **Pattern**: Matches docling-service pattern exactly

#### manage.sh (New)
```bash
./manage.sh start          # Start service
./manage.sh stop           # Stop service
./manage.sh restart        # Restart service
./manage.sh status         # Full status check
./manage.sh logs           # Follow logs
./manage.sh logs-tail      # Last 100 lines
./manage.sh shell          # Open container shell
./manage.sh test           # Run API tests
./manage.sh test-custom    # Test with custom prompt
./manage.sh rebuild        # Rebuild from scratch
./manage.sh cleanup        # Remove container
```

### 6. docker-compose.yml
- **Before**: Used by deploy.sh
- **After**: Still present for reference, but not used by deploy.sh
- **Change**: Added volume mounts for models and logs

### 7. Documentation
- **Updated**: QUICKSTART.md - reflects new deployment process
- **New**: DEPLOYMENT_NOTE.md - explains H-Tiny choice
- **New**: MODEL_COMPARISON.md - helps choose models
- **New**: CHANGES.md - this document

## File Structure

```
granite-4.0/
├── deploy.sh              # ✨ UPDATED - Single deployment script
├── manage.sh              # ✨ NEW - Management utilities
├── Dockerfile             # UPDATED - H-Tiny instead of H-Micro
├── docker-compose.yml     # UPDATED - Volume mounts added
├── .env.example           # Unchanged
├── test_crewai_integration.py  # UPDATED - H-Tiny default
│
├── QUICKSTART.md          # ✨ UPDATED - New deployment flow
├── DEPLOYMENT_NOTE.md     # ✨ NEW - Model selection rationale
├── MODEL_COMPARISON.md    # NEW - Model comparison guide
├── CREWAI_INTEGRATION.md  # Unchanged
├── README.md              # Unchanged
├── CHANGES.md             # ✨ NEW - This file
│
├── deploy.sh.old          # 📦 Backup of old deploy.sh
└── QUICKSTART.md.old      # 📦 Backup of old QUICKSTART
```

## Migration Guide

If you already deployed the old version:

```bash
# 1. Stop old deployment
./deploy.sh.old stop  # or docker stop granite-4.0-api

# 2. Remove old container
docker rm granite-4.0-api

# 3. Deploy new version
./deploy.sh

# The model will be re-downloaded (~4.5GB) but only this once
# Future rebuilds will use the persistent ./models/ directory
```

## Why These Changes?

### Simplicity
- Single-command deployment
- Clear separation of deployment vs. management
- Easier to maintain and troubleshoot

### Robustness
- Persistent storage prevents re-downloads
- Auto-restart survives server reboots
- Production-ready configuration

### Better Defaults
- H-Tiny provides better quality
- Still fast enough with MoE (1B active params)
- Reasonable resource requirements

## Testing

After deployment:

```bash
# 1. Quick status check
./manage.sh status

# 2. Run test suite
./manage.sh test

# 3. Test with CrewAI (if available)
python test_crewai_integration.py
```

## Rollback

To rollback to the old deployment method:

```bash
# 1. Restore old scripts
mv deploy.sh.old deploy.sh

# 2. Remove new files
rm manage.sh

# 3. Redeploy
./deploy.sh build
./deploy.sh start
```

(But you probably won't need to - the new method is better!)

---

*Updated: October 3, 2025*

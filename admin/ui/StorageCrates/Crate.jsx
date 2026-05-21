import React, { useState } from 'react';
import { Chip, IconButton, Tooltip } from '@material-ui/core';
import { makeStyles } from '@material-ui/styles';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { toast } from 'react-toastify';

import Nui from '../../util/Nui';
import { Modal } from '../../components';

const useStyles = makeStyles((theme) => ({
  row: {
    display: 'flex',
    alignItems: 'flex-start',
    gap: 12,
    padding: '12px 14px',
    background: theme.palette.secondary.light,
    border: `1px solid ${theme.palette.border.divider}`,
    borderRadius: 4,
    marginBottom: 6,
  },
  idBadge: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    minWidth: 52,
    minHeight: 28,
    borderRadius: 4,
    padding: '0 8px',
    background: 'rgba(124, 58, 237, 0.12)',
    border: '1px solid rgba(124, 58, 237, 0.25)',
    fontSize: 10,
    fontWeight: 700,
    color: theme.palette.primary.light,
    flexShrink: 0,
    wordBreak: 'break-all',
    textAlign: 'center',
  },
  info: {
    flex: 1,
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))',
    gap: 10,
    minWidth: 0,
  },
  colLabel: {
    display: 'block',
    fontSize: 10,
    fontWeight: 700,
    letterSpacing: '0.08em',
    textTransform: 'uppercase',
    color: theme.palette.text.info,
    marginBottom: 2,
  },
  colValue: {
    display: 'block',
    fontSize: 12,
    fontWeight: 500,
    color: theme.palette.text.main,
    wordBreak: 'break-word',
  },
  actions: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: 6,
    alignItems: 'center',
    flexShrink: 0,
    maxWidth: 220,
    justifyContent: 'flex-end',
  },
  actionBtn: {
    minWidth: 32,
    width: 32,
    height: 32,
    padding: 0,
  },
  statusChip: {
    height: 20,
    fontSize: 10,
    fontWeight: 700,
    letterSpacing: '0.06em',
    borderRadius: 3,
    marginBottom: 6,
  },
}));

const statusStyles = {
  active: { background: 'rgba(5, 150, 105, 0.15)', color: '#10B981', border: '1px solid rgba(5, 150, 105, 0.3)' },
  database_only: { background: 'rgba(245, 158, 11, 0.15)', color: '#FBBF24', border: '1px solid rgba(245, 158, 11, 0.3)' },
  missing_entity: { background: 'rgba(239, 68, 68, 0.15)', color: '#F87171', border: '1px solid rgba(239, 68, 68, 0.3)' },
};

const statusLabels = {
  active: 'Active',
  database_only: 'Database Only',
  missing_entity: 'Missing Entity',
};

export default ({ crate, onUpdate }) => {
  const classes = useStyles();
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [busy, setBusy] = useState(false);

  const coordStr = crate.coords && crate.coords.x
    ? `${Number(crate.coords.x).toFixed(1)}, ${Number(crate.coords.y).toFixed(1)}, ${Number(crate.coords.z).toFixed(1)}`
    : '—';

  const ownerLabel = crate.ownerName
    ? `${crate.ownerName} (${crate.ownerSid})`
    : (crate.ownerSid || '—');

  const copyCoords = () => {
    if (!crate.coords || crate.coords.x == null) {
      toast.error('No coordinates available');
      return;
    }

    Nui.copyClipboard(
      `vector3(${Number(crate.coords.x).toFixed(3)}, ${Number(crate.coords.y).toFixed(3)}, ${Number(crate.coords.z).toFixed(3)})`
    );
    toast.success('Copied coordinates');
  };

  const runAction = async (event, payload, successMsg) => {
    setBusy(true);
    try {
      const res = await (await Nui.send(event, payload)).json();
      if (res?.success) {
        toast.success(res.message || successMsg);
        if (onUpdate) onUpdate();
      } else {
        toast.error(res?.message || 'Action failed');
      }
    } catch {
      toast.error('Action failed');
    }
    setBusy(false);
  };

  const onTeleport = () => runAction('TeleportToStorageCrate', { crateId: crate.crateId, coords: crate.coords }, 'Teleported');
  const onWaypoint = () => runAction('SetStorageCrateWaypoint', { coords: crate.coords }, 'Waypoint set');
  const onRemoveEntity = () => runAction('RemoveStorageCrateEntity', { crateId: crate.crateId }, 'Entity removed');
  const onDelete = async () => {
    setShowDeleteModal(false);
    await runAction('DeleteStorageCrate', { crateId: crate.crateId }, 'Crate deleted');
  };

  const chipStyle = statusStyles[crate.status] || statusStyles.database_only;

  return (
    <>
      <div className={classes.row}>
        <div>
          <Chip
            label={statusLabels[crate.status] || crate.status || 'Unknown'}
            size="small"
            className={classes.statusChip}
            style={chipStyle}
          />
          <div className={classes.idBadge}>{crate.crateId}</div>
        </div>
        <div className={classes.info}>
          <div>
            <span className={classes.colLabel}>Owner</span>
            <span className={classes.colValue}>{ownerLabel}</span>
          </div>
          <div>
            <span className={classes.colLabel}>Location</span>
            <span className={classes.colValue}>
              {coordStr}
              {crate.coords?.route != null ? ` (route ${crate.coords.route})` : ''}
            </span>
          </div>
          <div>
            <span className={classes.colLabel}>Stash ID</span>
            <span className={classes.colValue}>{crate.stashId || '—'}</span>
          </div>
          <div>
            <span className={classes.colLabel}>Tier</span>
            <span className={classes.colValue}>{crate.tier || '—'}</span>
          </div>
          <div>
            <span className={classes.colLabel}>Created</span>
            <span className={classes.colValue}>
              {crate.createdAt ? new Date(crate.createdAt).toLocaleString() : '—'}
            </span>
          </div>
        </div>
        <div className={classes.actions}>
          <Tooltip title="Teleport">
            <span>
              <IconButton size="small" className={classes.actionBtn} onClick={onTeleport} disabled={busy}>
                <FontAwesomeIcon icon={['fas', 'location-crosshairs']} />
              </IconButton>
            </span>
          </Tooltip>
          <Tooltip title="Set waypoint">
            <span>
              <IconButton size="small" className={classes.actionBtn} onClick={onWaypoint} disabled={busy}>
                <FontAwesomeIcon icon={['fas', 'map-pin']} />
              </IconButton>
            </span>
          </Tooltip>
          <Tooltip title="Copy coords">
            <span>
              <IconButton size="small" className={classes.actionBtn} onClick={copyCoords} disabled={busy}>
                <FontAwesomeIcon icon={['fas', 'copy']} />
              </IconButton>
            </span>
          </Tooltip>
          <Tooltip title="Remove world entity">
            <span>
              <IconButton size="small" className={classes.actionBtn} onClick={onRemoveEntity} disabled={busy || crate.status !== 'active'}>
                <FontAwesomeIcon icon={['fas', 'cube']} />
              </IconButton>
            </span>
          </Tooltip>
          <Tooltip title="Delete crate">
            <span>
              <IconButton
                size="small"
                className={classes.actionBtn}
                onClick={() => setShowDeleteModal(true)}
                disabled={busy}
                style={{ color: '#F87171' }}
              >
                <FontAwesomeIcon icon={['fas', 'trash']} />
              </IconButton>
            </span>
          </Tooltip>
        </div>
      </div>

      <Modal
        open={showDeleteModal}
        title="Delete Storage Crate"
        onClose={() => setShowDeleteModal(false)}
        onAccept={onDelete}
        acceptText="Delete"
      >
        <p>
          Delete crate <strong>{crate.crateId}</strong> for owner SID <strong>{crate.ownerSid}</strong>?
        </p>
        <p>This removes the database record, clears the stash, and despawns the world entity. This cannot be undone.</p>
      </Modal>
    </>
  );
};

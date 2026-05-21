import React, { useEffect, useState } from 'react';
import { useLocation } from 'react-router-dom';
import { Grid, TextField, InputAdornment, IconButton, Pagination, Button } from '@material-ui/core';
import { makeStyles } from '@material-ui/styles';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { toast } from 'react-toastify';

import Nui from '../../util/Nui';
import { Loader } from '../../components';

import Crate from './Crate';

const useStyles = makeStyles((theme) => ({
  wrapper: {
    padding: '20px 10px 20px 20px',
    height: '100%',
    display: 'flex',
    flexDirection: 'column',
    boxSizing: 'border-box',
  },
  header: {
    flex: '0 0 auto',
    marginBottom: 14,
  },
  pageTitle: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    fontSize: 11,
    fontWeight: 700,
    letterSpacing: '0.12em',
    textTransform: 'uppercase',
    color: theme.palette.text.info,
    marginBottom: 14,
    '&::before': {
      content: '""',
      display: 'inline-block',
      width: 3,
      height: 13,
      background: theme.palette.primary.main,
      borderRadius: 2,
    },
  },
  results: {
    flex: '1 1 auto',
    minHeight: 0,
    display: 'flex',
    flexDirection: 'column',
  },
  items: {
    flex: '1 1 auto',
    overflowY: 'auto',
    overflowX: 'hidden',
    paddingRight: 10,
  },
  actionBtn: {
    height: 40,
    fontSize: 12,
    fontWeight: 600,
    letterSpacing: '0.04em',
  },
  empty: {
    textAlign: 'center',
    color: theme.palette.text.info,
    padding: 40,
    fontSize: 14,
  },
}));

export default () => {
  const classes = useStyles();
  const location = useLocation();
  const PER_PAGE = 15;

  const [searched, setSearched] = useState('');
  const [pages, setPages] = useState(1);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [results, setResults] = useState([]);
  const [filtered, setFiltered] = useState([]);

  useEffect(() => {
    fetch(false);
  }, [location.pathname]);

  useEffect(() => {
    setPages(Math.max(1, Math.ceil(filtered.length / PER_PAGE)));
    setPage(1);
  }, [filtered]);

  useEffect(() => {
    const term = searched.trim().toLowerCase();

    setFiltered(
      results.filter((crate) => {
        if (!term) return true;

        const ownerName = (crate.ownerName || '').toLowerCase();
        const ownerSid = String(crate.ownerSid || '').toLowerCase();
        const crateId = String(crate.crateId || '').toLowerCase();
        const stashId = String(crate.stashId || '').toLowerCase();
        const tier = String(crate.tier || '').toLowerCase();

        return (
          crateId.includes(term)
          || ownerSid.includes(term)
          || ownerName.includes(term)
          || stashId.includes(term)
          || tier.includes(term)
          || String(crate.id || '').includes(term)
        );
      })
    );
  }, [results, searched]);

  const fetch = async (reload) => {
    setLoading(true);

    try {
      const res = await (await Nui.send('GetStorageCrates', { reload: reload === true })).json();
      if (res) {
        setResults(res);
      } else {
        setResults([]);
        toast.error('Failed to load storage crates');
      }
    } catch {
      setResults([]);
      toast.error('Failed to load storage crates');
    }

    setLoading(false);
  };

  const onClear = () => setSearched('');
  const onPagi = (e, p) => setPage(p);

  return (
    <div className={classes.wrapper}>
      <div className={classes.header}>
        <div className={classes.pageTitle}>Storage Crates</div>
        <Grid container spacing={1}>
          <Grid item xs={12}>
            <Button
              fullWidth
              className={classes.actionBtn}
              variant="outlined"
              onClick={() => fetch(true)}
            >
              <FontAwesomeIcon icon={['fas', 'rotate-right']} style={{ marginRight: 8 }} />
              Refresh &amp; Reload Crates
            </Button>
          </Grid>
          <Grid item xs={12}>
            <TextField
              fullWidth
              variant="outlined"
              name="search"
              value={searched}
              onChange={(e) => setSearched(e.target.value)}
              label="Search by Crate ID, Owner SID, Name, Stash, or Tier"
              InputProps={{
                endAdornment: (
                  <InputAdornment position="end">
                    {searched !== '' && (
                      <IconButton type="button" onClick={onClear}>
                        <FontAwesomeIcon icon={['fas', 'xmark']} />
                      </IconButton>
                    )}
                  </InputAdornment>
                ),
              }}
            />
          </Grid>
        </Grid>
      </div>
      <div className={classes.results}>
        {loading ? (
          <Loader text="Loading Storage Crates" />
        ) : (
          <>
            <div className={classes.items}>
              {filtered.length === 0 ? (
                <div className={classes.empty}>No storage crates found.</div>
              ) : (
                filtered
                  .slice((page - 1) * PER_PAGE, page * PER_PAGE)
                  .map((crate) => (
                    <Crate key={crate.crateId} crate={crate} onUpdate={() => fetch(false)} />
                  ))
              )}
            </div>
            {pages > 1 && (
              <Pagination
                variant="outlined"
                shape="rounded"
                color="primary"
                page={page}
                count={pages}
                onChange={onPagi}
              />
            )}
          </>
        )}
      </div>
    </div>
  );
};

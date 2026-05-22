# Pulsar Admin – Storage Crates Integration

This adds a full **Storage Crates** management page into Pulsar Admin.

Admins will be able to:
- View all crates
- Teleport to crates
- Delete crates
- Manage crates directly from the admin panel

---

# Installation

## 1. Edit `pulsar-admin/fxmanifest.lua`

### Under:

```lua
"client/doorlock.lua",
```

### Add:

```lua
"client/storage_crates.lua",
```

---

### Under:

```lua
"server/doorlock.lua",
```

### Add:

```lua
"server/storage_crates.lua",
```

---

# 2. Register The Callbacks

Open:

```txt
pulsar-admin/server/callbacks.lua
```

Find:

```lua
function RegisterCallbacks()
    if RegisterDoorlockCallbacks then
        RegisterDoorlockCallbacks()
    end
```

Add this underneath the function:

```lua
if RegisterStorageCrateCallbacks then
    RegisterStorageCrateCallbacks()
end
```

---

# 3. Edit `ui/src/containers/groups/staff.jsx`

## Add Import

Find:

```js
DoorlockView,
```

Add underneath:

```js
StorageCrates,
```

---

## Add Route

Find:

```jsx
<Route exact path="/doorlock/:id" component={DoorlockView} />
```

Add underneath:

```jsx
<Route exact path="/storage-crates" component={StorageCrates} />
```

---

## Add Sidebar Button

Find:

```js
{
    name: "doorlocks",
    icon: ["fas", "door-closed"],
    label: "Doorlocks",
    path: "/doorlocks",
    exact: true,
},
```

Add underneath:

```js
{
    name: "storage-crates",
    icon: ["fas", "box"],
    label: "Storage Crates",
    path: "/storage-crates",
    exact: true,
},
```

---

# 4. Edit `ui/src/pages/index.js`

## Add Import

Find:

```js
import DoorlockView from "./View/Doorlock";
```

Add underneath:

```js
import StorageCrates from "./StorageCrates";
```

---

## Export The Page

Find:

```js
DoorlockView,
```

Add underneath:

```js
StorageCrates,
```

---

# 5. Copy The Required Files

## Server File

Copy:

```txt
pulsar-storagecrates/admin/server/storage_crates.lua
```

Into:

```txt
pulsar-admin/server/
```

---

## Client File

Copy:

```txt
pulsar-storagecrates/admin/client/storage_crates.lua
```

Into:

```txt
pulsar-admin/client/
```

---

## UI Folder

Copy:

```txt
pulsar-storagecrates/admin/ui/StorageCrates
```

Into:

```txt
pulsar-admin/ui/src/pages/
```

---

# 6. Build The UI

Open a terminal inside:

```txt
pulsar-admin/ui
```

Run:

```bash
bun run build
```

or

```bash
npm run build
```

---

# 7. Restart The Resource

```bash
ensure pulsar-admin
```

---

# Done

You should now see a new **Storage Crates** page inside Pulsar Admin.
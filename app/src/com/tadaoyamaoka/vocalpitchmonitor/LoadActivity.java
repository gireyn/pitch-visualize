package com.tadaoyamaoka.vocalpitchmonitor;

import android.content.Intent;
import android.os.Bundle;
import android.util.SparseBooleanArray;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.ListAdapter;
import android.widget.ListView;
import android.app.ActionBar;
import android.app.Activity;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Iterator;

public class LoadActivity extends Activity {
    /* JADX INFO: Access modifiers changed from: protected */
    @Override // androidx.fragment.app.FragmentActivity, androidx.activity.ComponentActivity, androidx.core.app.ComponentActivity, android.app.Activity
    public void onCreate(Bundle bundle) {
        String[] fileList;
        super.onCreate(bundle);
        setContentView(R.layout.layout_load);
        ActionBar supportActionBar = getActionBar();
        if (supportActionBar != null) {
            supportActionBar.setDisplayHomeAsUpEnabled(true);
        }
        ArrayList arrayList = new ArrayList();
        for (String str : fileList()) {
            if (str.endsWith(".wav")) {
                arrayList.add(str);
            }
        }
        Collections.sort(arrayList);
        Collections.reverse(arrayList);
        ListView listView = (ListView) findViewById(R.id.listFiles);
        listView.setAdapter((ListAdapter) new ArrayAdapter(this, 17367056, arrayList));
        listView.setChoiceMode(2);
        listView.setOnItemClickListener(new AdapterView.OnItemClickListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.LoadActivity.1
            @Override // android.widget.AdapterView.OnItemClickListener
            public void onItemClick(AdapterView<?> adapterView, View view, int i, long j) {
                LoadActivity.this.invalidateOptionsMenu();
            }
        });
    }

    @Override // android.app.Activity
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.menu_load, menu);
        return true;
    }

    @Override // android.app.Activity
    public boolean onPrepareOptionsMenu(Menu menu) {
        SparseBooleanArray checkedItemPositions = ((ListView) findViewById(R.id.listFiles)).getCheckedItemPositions();
        int i = 0;
        for (int i2 = 0; i2 < checkedItemPositions.size(); i2++) {
            i += checkedItemPositions.valueAt(i2) ? 1 : 0;
        }
        for (int i3 = 0; i3 < menu.size(); i3++) {
            MenuItem item = menu.getItem(i3);
            int itemId = item.getItemId();
            if (itemId != R.id.action_delete) {
                if (itemId == R.id.action_load) {
                    if (i == 1) {
                        item.setEnabled(true);
                    } else {
                        item.setEnabled(false);
                    }
                }
            } else if (i >= 1) {
                item.setEnabled(true);
            } else {
                item.setEnabled(false);
            }
        }
        return super.onPrepareOptionsMenu(menu);
    }

    @Override // android.app.Activity
    public boolean onOptionsItemSelected(MenuItem menuItem) {
        int itemId = menuItem.getItemId();
        ListView listView = (ListView) findViewById(R.id.listFiles);
        SparseBooleanArray checkedItemPositions = listView.getCheckedItemPositions();
        ArrayList arrayList = new ArrayList();
        for (int i = 0; i < checkedItemPositions.size(); i++) {
            int keyAt = checkedItemPositions.keyAt(i);
            if (checkedItemPositions.get(keyAt)) {
                arrayList.add(listView.getItemAtPosition(keyAt).toString());
            }
        }
        if (itemId == 16908332) {
            finish();
            return true;
        } else if (itemId == R.id.action_delete) {
            for (int i2 = 0; i2 < checkedItemPositions.size(); i2++) {
                int keyAt2 = checkedItemPositions.keyAt(i2);
                if (checkedItemPositions.get(keyAt2)) {
                    listView.setItemChecked(keyAt2, false);
                }
            }
            ArrayAdapter arrayAdapter = (ArrayAdapter) listView.getAdapter();
            Iterator it = arrayList.iterator();
            while (it.hasNext()) {
                String str = (String) it.next();
                deleteFile(str);
                arrayAdapter.remove(str);
            }
            invalidateOptionsMenu();
            return true;
        } else if (itemId != R.id.action_load) {
            return super.onOptionsItemSelected(menuItem);
        } else {
            setResult(-1, new Intent().putExtra("FILE_NAME", (String) arrayList.get(0)));
            finish();
            return true;
        }
    }
}

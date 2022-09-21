/*
 * Copyright 2020 Board of Trustees of the University of Illinois.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package edu.illinois.rokwire.navigation.model;

import com.google.android.gms.maps.model.LatLng;

import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

import edu.illinois.rokwire.Utils;

public class NavPolyline {
    private final String points;

    public NavPolyline(JSONObject json) {
        this.points = Utils.Json.getStringValueForKey(json, "points");
    }

    public String getPoints() {
        return points;
    }

    public List<NavCoord> getNavCoordinates() {
        return NavCoord.createListFromEncodedString(points);
    }

    public List<LatLng> getLatLngCoordinates() {
        List<NavCoord> coordinates = getNavCoordinates();
        if (coordinates == null) {
            return null;
        }
        List<LatLng> latLngCoordinates = new ArrayList<>();
        for (NavCoord navCoord : coordinates) {
            latLngCoordinates.add(navCoord.toLatLng());
        }
        return latLngCoordinates;
    }
}

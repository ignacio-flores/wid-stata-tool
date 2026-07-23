package com.wid;

import java.net.*;
import java.util.*;

//import javax.xml.crypto.Data;

import java.io.*;
import org.json.*;
import com.stata.sfi.*;

public class WIDDownloader {

    private static final String apiKey = "rYFByOB0ioaPATwHtllMI71zLOZSK0Ic5veQonJP";
    private static final String ENVIRONMENT = "prod";  // Change to "dev" or "prod" when needed
    private static final String BASE_API_URL = "https://rfap9nitz6.execute-api.eu-west-1.amazonaws.com/" + ENVIRONMENT;

    private static final String apiCountriesAvailableVariables = BASE_API_URL + "/countries-available-variables";
    private static final String apiCountriesVariables          = BASE_API_URL + "/countries-variables";
    private static final String apiCountriesVariablesMetadata  = BASE_API_URL + "/countries-variables-metadata";

    private static void debugPrint(String verbosity, String message) {
        if ("verbose".equalsIgnoreCase(verbosity)) {
            SFIToolkit.display("\n" + message);
        }
    }

    private static int maxSize(int current, String value) {
        if (value != null && value.length() > current) {
            return value.length();
        }
        return current;
    }

    private static String optString(JSONObject json, String key) {
        if (json == null || !json.has(key) || json.isNull(key)) {
            return "";
        }
        return json.optString(key, "");
    }

    private static double optDoubleOrMissing(JSONObject json, String key) {
        if (json == null || !json.has(key) || json.isNull(key)) {
            return Double.NaN;
        }

        Object value = json.opt(key);
        if (value instanceof Number) {
            return ((Number) value).doubleValue();
        }

        String stringValue = value.toString().trim();
        if (stringValue.length() == 0) {
            return Double.NaN;
        }

        try {
            return Double.parseDouble(stringValue);
        } catch (NumberFormatException e) {
            return Double.NaN;
        }
    }

    private static double optFirstDoubleOrMissing(JSONObject json, String firstKey, String secondKey) {
        double value = optDoubleOrMissing(json, firstKey);
        if (Double.isNaN(value)) {
            value = optDoubleOrMissing(json, secondKey);
        }
        return value;
    }

    private static double stataMissingIfNaN(double value) {
        if (Double.isNaN(value)) {
            return Missing.getValue();
        }
        return value;
    }

    private static JSONObject findObject(JSONArray array, String key) {
        if (array == null) {
            return new JSONObject();
        }

        for (int i = 0; i < array.length(); i++) {
            JSONObject item = array.optJSONObject(i);
            if (item == null || !item.has(key) || item.isNull(key)) {
                continue;
            }

            JSONObject object = item.optJSONObject(key);
            if (object != null) {
                return object;
            }
        }

        return new JSONObject();
    }

    private static JSONArray findArray(JSONArray array, String key) {
        if (array == null) {
            return new JSONArray();
        }

        for (int i = 0; i < array.length(); i++) {
            JSONObject item = array.optJSONObject(i);
            if (item == null || !item.has(key) || item.isNull(key)) {
                continue;
            }

            JSONArray found = item.optJSONArray(key);
            if (found != null) {
                return found;
            }
        }

        return new JSONArray();
    }

    private static String firstObjectName(JSONObject object) {
        String[] names = JSONObject.getNames(object);
        if (names == null || names.length == 0) {
            return "";
        }
        return names[0];
    }

    // Convert an S3 URI such as s3://bucket/key to a HTTPS URL
    private static String s3UriToHttps(String s3Uri) {
        if (s3Uri != null && s3Uri.startsWith("s3://")) {
            String path = s3Uri.substring(5); // remove prefix
            int slash = path.indexOf('/');
            if (slash > 0) {
                String bucket = path.substring(0, slash);
                String key = path.substring(slash + 1);
                return "https://" + bucket + ".s3.amazonaws.com/" + key;
            }
        }
        return s3Uri;
    }

    public static int importCountriesAvailableVariables(String[] args) {
      
        // Retrieve the arguments of the query
        String countries = args[0];
        String sixlet = args[1];
        String verbosity = args[2];

        // Create the query
        String query;
        try {
            String charset = java.nio.charset.StandardCharsets.UTF_8.name();
            query = String.format("countries=%s&variables=%s",
                URLEncoder.encode(countries, charset),
                URLEncoder.encode(sixlet, charset)
            );
        } catch (Exception e) {
            SFIToolkit.error("\nthe 'areas' argument contains invalid characters\n");
            return(198);
        }

        // Access the online database
        Scanner scanner;
        String response;
        try {
          
            // Print query 
            debugPrint(verbosity, "Calling API: " + apiCountriesAvailableVariables + "?" + query);
            
            // Perform the GET query
            URL queryURL = new URL(apiCountriesAvailableVariables + "?" + query);
            HttpURLConnection connection = (HttpURLConnection) queryURL.openConnection();
            connection.setRequestMethod("GET");
            connection.setRequestProperty("x-api-key", apiKey);

            // Read the response
            scanner = new Scanner(connection.getInputStream());
            response = new String();
            while (scanner.hasNext()) {
                response += scanner.nextLine();
            }
            scanner.close();

        } catch (Exception e) {
            SFIToolkit.error("\ncould not access the online WID.world database; please check your internet connection\n");
            return(677);
        }

        // Parse the results
        try {
            List<String> listVariable   = new ArrayList<String>();
            List<String> listCountry    = new ArrayList<String>();
            List<String> listPercentile = new ArrayList<String>();
            List<String> listAge        = new ArrayList<String>();
            List<String> listPop        = new ArrayList<String>();

            // Correction for cases where an array is returned
            JSONObject json;
            try {
                json = new JSONObject(response);
            } catch (JSONException e) {
                JSONArray jsonArray = new JSONArray(response);
                json = jsonArray.getJSONObject(0);
            }

            Iterator<String> variableIter = json.keys();
            while (variableIter.hasNext()) {
                String variable = variableIter.next();
                JSONObject jsonCountry = json.getJSONObject(variable);
                Iterator<String> countryIter = jsonCountry.keys();
                while (countryIter.hasNext()) {
                    String country = countryIter.next();
                    JSONArray jsonProperties = jsonCountry.getJSONArray(country);
                    Iterator propertiesIter = jsonProperties.iterator();
                    while (propertiesIter.hasNext()) {
                        JSONArray properties = (JSONArray) propertiesIter.next();

                        listVariable.add(variable);
                        listCountry.add(country);
                        listPercentile.add(properties.optString(0));
                        listAge.add(properties.optString(1));
                        listPop.add(properties.optString(2));
                    }
                }
            }

            // Fill the Stata dataset
            Data.addVarStr("variable", 6);
            Data.addVarStr("country", 5);
            Data.addVarStr("percentile", 14);
            Data.addVarStr("age", 3);
            Data.addVarStr("pop", 1);

            int obsCount = listVariable.size();
            Data.setObsCount(obsCount);

            int variableVariableIndex   = Data.getVarIndex("variable");
            int variableCountryIndex    = Data.getVarIndex("country");
            int variablePercentileIndex = Data.getVarIndex("percentile");
            int variableAgeIndex        = Data.getVarIndex("age");
            int variablePopIndex        = Data.getVarIndex("pop");

            for (int i = 0; i < obsCount; i++) {
                Data.storeStr(variableVariableIndex,   i + 1, listVariable.get(i));
                Data.storeStr(variableCountryIndex,    i + 1, listCountry.get(i));
                Data.storeStr(variablePercentileIndex, i + 1, listPercentile.get(i));
                Data.storeStr(variableAgeIndex,        i + 1, listAge.get(i));
                Data.storeStr(variablePopIndex,        i + 1, listPop.get(i));
            }
        } catch (Exception e) {
            SFIToolkit.error("\nserver response invalid; if the problem persists, please file bug report to stats@wid.world\n");
            SFIToolkit.error(e.toString());
            SFIToolkit.error("\n");
            return(674);
        }

        return(0);
    }

    public static int importCountriesVariables(String[] args) {
        // Retrieve the arguments of the query
        String countries = args[0];
        String variables = args[1];
        String verbosity = args.length > 3 ? args[3] : args[2];

        // Create the query
        String query;
        try {
            String charset = java.nio.charset.StandardCharsets.UTF_8.name();
            query = String.format("countries=%s&variables=%s",
                URLEncoder.encode(countries, charset),
                URLEncoder.encode(variables, charset)
            );
        } catch (Exception e) {
            SFIToolkit.error("\nthe arguments contains invalid characters\n");
            return(198);
        }

        // Access the online database
        Scanner scanner;
        String response;
        try {
          
            // Print query
            debugPrint(verbosity, "Calling API: " + apiCountriesVariables + "?" + query);

            // Perform the GET query
            URL queryURL = new URL(apiCountriesVariables + "?" + query);
            HttpURLConnection connection = (HttpURLConnection) queryURL.openConnection();
            connection.setRequestMethod("GET");
            connection.setRequestProperty("x-api-key", apiKey);

            // Read the response
            scanner = new Scanner(connection.getInputStream());
            response = new String();
            while (scanner.hasNext()) {
                response += scanner.nextLine();
            }
            scanner.close();
        } catch (Exception e) {
            SFIToolkit.error("\ncould not access the online WID.world database; please check your internet connection\n");
            return(677);
        }

        // Parse the results
        try {
            List<String>  listCountry    = new ArrayList<String>();
            List<String>  listVariable   = new ArrayList<String>();
            List<String>  listPercentile = new ArrayList<String>();
            List<String>  listAge        = new ArrayList<String>();
            List<String>  listPop        = new ArrayList<String>();
            List<Integer> listYear       = new ArrayList<Integer>();
            List<Double>  listValue      = new ArrayList<Double>();
            List<Double>  listDataQuality = new ArrayList<Double>();

            JSONObject json = new JSONObject(response);

            if ("payload_too_large".equals(json.optString("status"))) {
                //SFIToolkit.error("\n" + json.optString("message"));
                SFIToolkit.error("\n Downloading large data from alternative route (please wait)");
                String downloadUrl = json.optString("download_url");
                debugPrint(verbosity, "Downloading large payload from: " + downloadUrl);

                try {
                    URL dl = new URL(downloadUrl);
                    HttpURLConnection dlConn = (HttpURLConnection) dl.openConnection();
                    dlConn.setRequestMethod("GET");
                    Scanner dlScanner = new Scanner(dlConn.getInputStream());
                    StringBuilder sb = new StringBuilder();
                    while (dlScanner.hasNext()) {
                        sb.append(dlScanner.nextLine());
                    }
                    dlScanner.close();
                    response = sb.toString();
                    json     = new JSONObject(response);
                } catch (Exception ex) {
                    SFIToolkit.error("\nCould not download large result");
                    SFIToolkit.error(ex.toString());
                    return(0);
                }
            }


            Iterator<String> indicatorIter = json.keys();
            while (indicatorIter.hasNext()) {
                String indicator = indicatorIter.next();
                JSONArray indicatorData = json.getJSONArray(indicator);
                Iterator indicatorDataIter = indicatorData.iterator();
                while (indicatorDataIter.hasNext()) {
                    JSONObject countryData = (JSONObject) indicatorDataIter.next();

                    String country = JSONObject.getNames(countryData)[0];
                    
                    // Retrieve values
                    JSONArray countryValues = countryData.getJSONObject(country).getJSONArray("values");

                    Iterator countryValuesIter = countryValues.iterator();
                    while (countryValuesIter.hasNext()) {
                        JSONObject value = (JSONObject) countryValuesIter.next();

                        String[] parts = indicator.split("_");
                        int year = value.getInt("y");

                        listCountry.add(country);
                        listVariable.add(parts[0]);
                        listPercentile.add(parts[1]);
                        listAge.add(parts[2]);
                        listPop.add(parts[3]);
                        listYear.add(year);
                        listValue.add(value.optDouble("v"));
                        listDataQuality.add(optDoubleOrMissing(value, "dq"));
                    }
                }
            }

            // Fill the Stata dataset
            Data.addVarStr("variable", 6);
            Data.addVarStr("country", 5);
            Data.addVarStr("percentile", 14);
            Data.addVarStr("age", 3);
            Data.addVarStr("pop", 1);
            Data.addVarInt("year");
            Data.addVarDouble("value");
            Data.addVarDouble("data_quality");

            int obsCount = listVariable.size();
            Data.setObsCount(obsCount);

            int variableCountryIndex    = Data.getVarIndex("country");
            int variableVariableIndex   = Data.getVarIndex("variable");
            int variablePercentileIndex = Data.getVarIndex("percentile");
            int variableAgeIndex        = Data.getVarIndex("age");
            int variablePopIndex        = Data.getVarIndex("pop");
            int variableYearIndex       = Data.getVarIndex("year");
            int variableValueIndex      = Data.getVarIndex("value");
            int variableDataQualityIndex = Data.getVarIndex("data_quality");

            for (int i = 0; i < obsCount; i++) {
                Data.storeStr(variableCountryIndex,    i + 1, listCountry.get(i));
                Data.storeStr(variableVariableIndex,   i + 1, listVariable.get(i));
                Data.storeStr(variablePercentileIndex, i + 1, listPercentile.get(i));
                Data.storeStr(variableAgeIndex,        i + 1, listAge.get(i));
                Data.storeStr(variablePopIndex,        i + 1, listPop.get(i));
                Data.storeNum(variableYearIndex,       i + 1, listYear.get(i));
                Data.storeNum(variableValueIndex,      i + 1, listValue.get(i));
                Data.storeNum(variableDataQualityIndex, i + 1, stataMissingIfNaN(listDataQuality.get(i)));
            }
        } catch (Exception e) {
            SFIToolkit.error("\nserver response invalid; if the problem persists, please file bug report to stats@wid.world\n");
            SFIToolkit.error(e.toString());
            SFIToolkit.error("\n");
            return(674);
        }

        return(0);
    }

    public static int importCountriesVariablesMetadata(String[] args) {
        // Retrieve the arguments of the query
        String countries = args[0];
        String variables = args[1];
        String verbosity = args[2];  
        String mode = args.length > 3 ? args[3] : "compact";
        boolean scoreOnly = "score_only".equalsIgnoreCase(mode);

        // Create the query
        String query;
        try {
            String charset = java.nio.charset.StandardCharsets.UTF_8.name();
            query = String.format("countries=%s&variables=%s",
                URLEncoder.encode(countries, charset),
                URLEncoder.encode(variables, charset)
            );
        } catch (Exception e) {
            SFIToolkit.error("\nthe 'areas' argument contains invalid characters\n");
            return(198);
        }

        // Access the online database
        Scanner scanner;
        String response;
        try {
          
            // Print query
            debugPrint(verbosity, "Calling API: " + apiCountriesVariablesMetadata + "?" + query);

            // Perform the GET query
            URL queryURL = new URL(apiCountriesVariablesMetadata + "?" + query);
            HttpURLConnection connection = (HttpURLConnection) queryURL.openConnection();
            connection.setRequestMethod("GET");
            connection.setRequestProperty("x-api-key", apiKey);

            // Read the response
            scanner = new Scanner(connection.getInputStream());
            response = new String();
            while (scanner.hasNext()) {
                response += scanner.nextLine();
            }
            scanner.close();
        } catch (Exception e) {
            SFIToolkit.error("\ncould not access the online WID.world database; please check your internet connection\n");
            SFIToolkit.error(e.toString());
            SFIToolkit.error("\n");
            return(677);
        }

        // Parse the results
        try {
            List<String> listVariable     = new ArrayList<String>();
            List<String> listCountry      = new ArrayList<String>();
            List<String> listCountryName  = new ArrayList<String>();
            List<String> listPercentile   = new ArrayList<String>();
            List<String> listAgeCode      = new ArrayList<String>();
            List<String> listPopCode      = new ArrayList<String>();
            int sizeCountryName = 1;

            List<String> listShortName = new ArrayList<String>();
            List<String> listShortDes  = new ArrayList<String>();
            int sizeShortName = 1;
            int sizeShortDes = 1;

            List<String> listPop = new ArrayList<String>();
            int sizePop = 1;

            List<String> listAge = new ArrayList<String>();
            int sizeAge = 1;

            List<String> listSource = new ArrayList<String>();
            List<String> listMethod = new ArrayList<String>();
            List<Double> listAvgQuality = new ArrayList<Double>();
            int sizeSource = 1;
            int sizeMethod = 1;

            JSONArray responseArray = new JSONArray(response);
            JSONArray json = new JSONArray();
            if (responseArray.length() > 0) {
                JSONObject responseObject = responseArray.optJSONObject(0);
                if (responseObject != null) {
                    JSONArray metadataFunc = responseObject.optJSONArray("metadata_func");
                    if (metadataFunc != null) {
                        json = metadataFunc;
                    }
                }
            }

            // First, loop over the indicator
            Iterator indicatorIter = json.iterator();
            while (indicatorIter.hasNext()) {
                JSONObject indicator = (JSONObject) indicatorIter.next();
                String indicatorName = firstObjectName(indicator);
                if (indicatorName.length() == 0) {
                    continue;
                }

                JSONArray indicatorData = indicator.optJSONArray(indicatorName);
                if (indicatorData == null) {
                    continue;
                }

                String[] parts = indicatorName.split("_");
                if (parts.length < 4) {
                    continue;
                }
                String variable = parts[0];
                String percentile = parts[1];
                String ageCode = parts[2];
                String popCode = parts[3];
                String concept = variable.length() >= 6 ? variable.substring(1, 6) : variable;

                JSONObject nameJSON = scoreOnly ? new JSONObject() : findObject(indicatorData, "name");
                JSONObject popJSON  = scoreOnly ? new JSONObject() : findObject(indicatorData, "pop");
                JSONObject ageJSON  = scoreOnly ? new JSONObject() : findObject(indicatorData, "age");
                JSONArray unitJSON   = findArray(indicatorData, "units");
                JSONArray notesArray = findArray(indicatorData, "notes");
                JSONObject notesJSON = notesArray.length() > 0 && notesArray.optJSONObject(0) != null
                    ? notesArray.optJSONObject(0)
                    : new JSONObject();

                String shortName = optString(nameJSON, "shortname");
                String shortDes = optString(nameJSON, "shortdes");
                if (shortDes.length() == 0) {
                    shortDes = optString(nameJSON, "simpledes");
                }

                String pop = optString(popJSON, "longdes");

                if (optString(ageJSON, "agecode").length() > 0) {
                    ageCode = optString(ageJSON, "agecode");
                }
                String age = optString(ageJSON, "fullname");

                Iterator countryIter = unitJSON.iterator();
                while (countryIter.hasNext()) {
                    JSONObject countryUnits = (JSONObject) countryIter.next();

                    String country = optString(countryUnits, "country");
                    String countryName = optString(countryUnits, "country_name");

                    String source = "";
                    String method = "";
                    double avgQuality = Double.NaN;
                    
                    // Find matching source and method, if any
                    if (!notesJSON.isNull(concept)) {
                        JSONArray countryNotesArray = notesJSON.optJSONArray(concept);
                        Iterator countryNotesIter = countryNotesArray == null
                            ? new JSONArray().iterator()
                            : countryNotesArray.iterator();
                        while (countryNotesIter.hasNext()) {
                            JSONObject countryNotes = (JSONObject) countryNotesIter.next();
                            if (optString(countryNotes, "alpha2").equals(country)) {
                                if (!scoreOnly) {
                                    source = optString(countryNotes, "source");
                                    method = optString(countryNotes, "method");
                                }
                                avgQuality = optFirstDoubleOrMissing(countryNotes, "data_quality", "data_quality_score");
                                
                                break;
                            }
                        }
                    }

                    listVariable.add(variable);
                    listPercentile.add(percentile);
                    listCountry.add(country);
                    listAgeCode.add(ageCode);
                    listPopCode.add(popCode);
                    listAvgQuality.add(avgQuality);

                    if (!scoreOnly) {
                        listCountryName.add(countryName);
                        sizeCountryName = maxSize(sizeCountryName, countryName);

                        listShortName.add(shortName);
                        sizeShortName = maxSize(sizeShortName, shortName);
                        listShortDes.add(shortDes);
                        sizeShortDes = maxSize(sizeShortDes, shortDes);

                        listPop.add(pop);
                        sizePop = maxSize(sizePop, pop);

                        listAge.add(age);
                        sizeAge = maxSize(sizeAge, age);

                        listSource.add(source);
                        sizeSource = maxSize(sizeSource, source);
                        listMethod.add(method);
                        sizeMethod = maxSize(sizeMethod, method);
                    }
                }
            }

            // Fill the Stata dataset
            Data.addVarStr("variable", 6);
            Data.addVarStr("percentile", 14);
            Data.addVarStr("country", 5);
            Data.addVarStr("agecode", 3);
            Data.addVarStr("popcode", 1);
            Data.addVarDouble("avg_quality");

            if (!scoreOnly) {
                Data.addVarStr("countryname", sizeCountryName);
                Data.addVarStr("shortname", sizeShortName);
                Data.addVarStr("shortdes", sizeShortDes);
                Data.addVarStr("pop", sizePop);
                Data.addVarStr("age", sizeAge);
                Data.addVarStr("source", sizeSource);
                Data.addVarStr("method", sizeMethod);
            }

            int obsCount = listVariable.size();
            Data.setObsCount(obsCount);

            int variableVariableIndex    = Data.getVarIndex("variable");
            int variablePercentileIndex  = Data.getVarIndex("percentile");
            int variableCountryIndex     = Data.getVarIndex("country");
            int variableAgeCodeIndex     = Data.getVarIndex("agecode");
            int variablePopCodeIndex     = Data.getVarIndex("popcode");
            int variableAvgQualityIndex  = Data.getVarIndex("avg_quality");
            int variableCountryNameIndex = scoreOnly ? -1 : Data.getVarIndex("countryname");
            int variableShortNameIndex   = scoreOnly ? -1 : Data.getVarIndex("shortname");
            int variableShortDesIndex    = scoreOnly ? -1 : Data.getVarIndex("shortdes");
            int variablePopIndex         = scoreOnly ? -1 : Data.getVarIndex("pop");
            int variableAgeIndex         = scoreOnly ? -1 : Data.getVarIndex("age");
            int variableSourceIndex      = scoreOnly ? -1 : Data.getVarIndex("source");
            int variableMethodIndex      = scoreOnly ? -1 : Data.getVarIndex("method");

            for (int i = 0; i < obsCount; i++) {
                Data.storeStr(variableVariableIndex,    i + 1, listVariable.get(i));
                Data.storeStr(variablePercentileIndex,  i + 1, listPercentile.get(i));
                Data.storeStr(variableCountryIndex,     i + 1, listCountry.get(i));
                Data.storeStr(variableAgeCodeIndex,     i + 1, listAgeCode.get(i));
                Data.storeStr(variablePopCodeIndex,     i + 1, listPopCode.get(i));
                Data.storeNum(variableAvgQualityIndex, i + 1, stataMissingIfNaN(listAvgQuality.get(i)));

                if (!scoreOnly) {
                    Data.storeStr(variableCountryNameIndex, i + 1, listCountryName.get(i));
                    Data.storeStr(variableShortNameIndex,   i + 1, listShortName.get(i));
                    Data.storeStr(variableShortDesIndex,    i + 1, listShortDes.get(i));
                    Data.storeStr(variablePopIndex,         i + 1, listPop.get(i));
                    Data.storeStr(variableAgeIndex,         i + 1, listAge.get(i));
                    Data.storeStr(variableSourceIndex,      i + 1, listSource.get(i));
                    Data.storeStr(variableMethodIndex,      i + 1, listMethod.get(i));
                }
            }
        } catch (Exception e) {
            SFIToolkit.error("\nserver response invalid; if the problem persists, please file bug report to stats@wid.world\n");
            SFIToolkit.error(e.toString());
            SFIToolkit.error("\n");
            return(674);
        }

        return(0);
    }

}

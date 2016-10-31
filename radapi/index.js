#!/usr/bin/env node
/*jshint esversion: 6 */
"use strict";

var http = require("http");
var path = require("path");

var express = require("express");
var RED = require("node-red");

// See https://nodered.org/docs/configuration
var settings = {
    uiPort: 1880,
    uiHost: "0.0.0.0",
    httpAdminRoot: "/edit/",
    httpNodeRoot: "/endpoints/",
    flowFile: "flows.json",
    flowFilePretty: true,
    userDir: path.resolve(__dirname, "data"),
    nodesDir: path.resolve(__dirname, "data/nodes"),
    paletteCategories: ["subflows", "input", "output", "function", "advanced", "storage", "social", "analysis"],
    httpStatic: "public",
    disableEditor: false,
    mqttReconnectTime: 15000,
    serialReconnectTime: 15000,
    socketReconnectTime: 10000,
    socketTimeout: 120000,
    debugMaxLength: 5000,
    functionGlobalContext: {
        os: require('os'),
        crypto: require('crypto'),
        _: require('underscore'),
        async: require('async')
    },
    httpNodeCors: {
        origin: "*",
        methods: "GET,PUT,PATCH,POST,DELETE"
    },
    swagger: {
        template: {
            swagger: "2.0",
            info: {
                title: "z3r0",
                description: "<a href=/edit target=_blank><img src=/raspberry-pi-pinout.png width=500 height=156></a>",
                version: "0.0.0"
            }
        }
    },
    logging: {
        console: {
            level: "info",
            metrics: false
        }
    }
};

var app = express();
var server = http.createServer(app);

app.set("etag", "strong");
app.use("/", express.static(path.resolve(__dirname, "public")));
RED.init(server, settings);
app.use(settings.httpAdminRoot, RED.httpAdmin);
app.use(settings.httpNodeRoot, RED.httpNode);
server.listen(settings.uiPort);
RED.start();

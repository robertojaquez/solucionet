<%@ Page Title="" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Paginas.aspx.cs" Inherits="Website.Paginas"  validateRequest="false" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server" width="100%;">
    <div id="div_sesion" runat="server" visible="false"></div>
    <div id="div_pagina" runat="server" visible="false"></div>
    <div id="div_contenido" runat="server" enableviewstate="False"></div>
    <iframe id="frame_impresion" width="0" height="0" frameborder="0" style="display:none; width:0px; height:0px; position: absolute; border:0px;"></iframe>
</asp:Content>

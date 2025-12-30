<%@ Page Title="" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="NoBienvenido.aspx.cs" Inherits="Website.NoBienvenido" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
<script language='javascript'>
                     setTimeout(function(){
                     swal({text:"Usted no tiene permisos para usar este módulo.",icon:"error"})
                    .then((value) => {window.location.href = "https://www.google.com";})
                     }, 50);
</script>
</asp:Content>

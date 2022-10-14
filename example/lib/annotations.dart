
import 'dart:convert';

import 'package:ar_location_view/ar_annotation.dart';

import 'libs.dart';

const  String data  = '{"data":[{"id":30,"nom":"Annonce test pour apps mobile","reference":"IMM140322130309","latitude":-18.891350176472404,"longitude":47.53384484183051,"altitude":0,"superficie":1,"prix":250000,"adresse":"4G5Q+F3 Antananarivo, Madagascar","action":"Vente","proprietaire":{"email":"ezekiela.rakoto@mailinator.com","prenom":"Ezekiela Anderson RAKOTOARISOA","adresse":"Bruxelles rue","phone":"123456"},"type":{"id":1,"libelle":"Maison"},"photos":[{"id":48,"src":"home-1622401_1280622f2efde51e9.jpeg","url":"https:\/\/back-immochv2.my-preprod.space\/media\/cache\/grid\/uploads\/imgsproperty\/home-1622401_1280622f2efde51e9.jpeg"}]},{"id":3,"nom":"Maison moderne \u00e0 vendre","reference":"IMM061021135400","latitude":-18.892139382302375,"longitude":47.534188164577664,"altitude":0,"superficie":220,"prix":7500,"adresse":"4G4M+RG9 Manjakaray Tananarive ","action":"Vente","proprietaire":{"email":"sitraka.rakoto@mailinator.com","prenom":"sitraka rakoto","adresse":"Bruxelle londre","phone":"123456"},"type":{"id":1,"libelle":"Maison"},"photos":[{"id":9,"src":"157375115_2517238051764768_4325708360853430989_o615d8e58c7729.jpeg","url":"https:\/\/back-immochv2.my-preprod.space\/media\/cache\/grid\/uploads\/imgsproperty\/157375115_2517238051764768_4325708360853430989_o615d8e58c7729.jpeg"},{"id":10,"src":"157202103_2517238045098102_4581351896630983648_o615d8e58c8caa.jpeg","url":"https:\/\/back-immochv2.my-preprod.space\/media\/cache\/resolve\/grid\/uploads\/imgsproperty\/157202103_2517238045098102_4581351896630983648_o615d8e58c8caa.jpeg"},{"id":11,"src":"156960118_2517238058431434_519953093276356297_o615d8e58c9b4c.jpeg","url":"https:\/\/back-immochv2.my-preprod.space\/media\/cache\/resolve\/grid\/uploads\/imgsproperty\/156960118_2517238058431434_519953093276356297_o615d8e58c9b4c.jpeg"},{"id":12,"src":"157197555_2517238055098101_3272504581748827555_o615d8e58ca119.jpeg","url":"https:\/\/back-immochv2.my-preprod.space\/media\/cache\/resolve\/grid\/uploads\/imgsproperty\/157197555_2517238055098101_3272504581748827555_o615d8e58ca119.jpeg"},{"id":13,"src":"157299676_2517238048431435_1845070019965283010_o615d8e58cc270.jpeg","url":"https:\/\/back-immochv2.my-preprod.space\/media\/cache\/resolve\/grid\/uploads\/imgsproperty\/157299676_2517238048431435_1845070019965283010_o615d8e58cc270.jpeg"}]},{"id":31,"nom":"Annonce test pour apps mobile","reference":"IMM140322130315","latitude":-18.892971751671887,"longitude":47.53900541187374,"altitude":0,"superficie":1,"prix":250000,"adresse":"4G5Q+F3 Tananarive, Madagascar","action":"Vente","proprietaire":{"email":"ezekiela.rakoto@mailinator.com","prenom":"Ezekiela Anderson RAKOTOARISOA","adresse":"Bruxelles rue","phone":"123456"},"type":{"id":1,"libelle":"Maison"},"photos":[{"id":49,"src":"home-1622401_1280622f2f03b6d61.jpeg","url":"https:\/\/back-immochv2.my-preprod.space\/media\/cache\/grid\/uploads\/imgsproperty\/home-1622401_1280622f2f03b6d61.jpeg"}]},{"id":20,"nom":"Annonce teste","reference":"IMM030322084017","latitude":-18.89579365605224,"longitude":47.53694547539079,"altitude":0,"superficie":10,"prix":100000,"adresse":"Rue du Progr\u00e8s 123, 1030 Schaerbeek, Belgique","action":"Vente","proprietaire":{"email":"ezekiela.rakoto@mailinator.com","prenom":"Ezekiela Anderson RAKOTOARISOA","adresse":"Bruxelles rue","phone":"123456"},"type":{"id":1,"libelle":"Maison"},"photos":[{"id":33,"src":"valuer622070e14c932.jpeg","url":"https:\/\/back-immochv2.my-preprod.space\/media\/cache\/grid\/uploads\/imgsproperty\/valuer622070e14c932.jpeg"},{"id":34,"src":"christmas-1827719_640622070e151645.png","url":"https:\/\/back-immochv2.my-preprod.space\/media\/cache\/resolve\/grid\/uploads\/imgsproperty\/christmas-1827719_640622070e151645.png"}]}]}';

Data dataFromJson(String str) => Data.fromJson(json.decode(str));

String dataToJson(Data data) => json.encode(data.toJson());

class Data {
  Data({
    required this.data,
  });

  List<ImmoAnnotation> data;

  factory Data.fromJson(Map<String, dynamic> json) => Data(
    data: List<ImmoAnnotation>.from(json["data"].map((x) => ImmoAnnotation.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "data": List<dynamic>.from(data.map((x) => x.toJson())),
  };
}

class ImmoAnnotation extends ArAnnotation {
  ImmoAnnotation({
    required this.id,
    required this.nom,
    this.urldetailbien,
    required this.reference,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.superficie,
    required this.prix,
    required this.adresse,
    required this.action,
  }) : super(
    position: positionBuilder(
      latitude: latitude,
      longitude: longitude,
    ),
    uid: reference,
  );

  int id;
  String nom;
  String reference;
  String? urldetailbien;
  double latitude;
  double longitude;
  int altitude;
  int superficie;
  int prix;
  String adresse;
  String action;

  factory ImmoAnnotation.fromJson(Map<String, dynamic> json) => ImmoAnnotation(
    id: json['id'],
    nom: json['nom'],
    reference: json['reference'],
    urldetailbien: json['urldetailbien'],
    latitude: json['latitude'].toDouble(),
    longitude: json['longitude'].toDouble(),
    altitude: json['altitude'],
    superficie: json['superficie'],
    prix: json['prix'],
    adresse: json['adresse'],
    action: json['action'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': nom,
    'reference': reference,
    'latitude': latitude,
    'longitude': longitude,
    'altitude': altitude,
    'superficie': superficie,
    'prix': prix,
    'adresse': adresse,
    'action': action,
  };
}